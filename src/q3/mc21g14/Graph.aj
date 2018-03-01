package q3.mc21g14;

import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.OptionalDouble;
import java.util.Stack;
import java.io.IOException;

import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.Signature;

// Write an aspect to obtain an input/output summary of the methods identified in Part 1 (where package
// name q1 is replaced throughout by q3).

// 1. For each method, the aspect should compute a histogram of the frequency of the values of the
//    int parameter passed as an input as well as of the returned int value.
//    At the end of the program execution, this information should be saved to files named 
//    <method signature>-hist.csv (i.e., one file for each method) using a comma separated
//    values format. Each histogram should have three columns: the value of interest, how many
//    times it has been used as an input, how many times it has been returned as a result.
// 2. The aspect should compute the frequency of failures, defined as the percentage of times that the
//    method does not return an int due to throwing an exception.
//    This information should be output to a file named failures.csv in comma-separated
//    values format, where each line provides the failure frequency of a method.
// 3. Finally, for each method the aspect should compute the average execution time and its standard
//    deviation across all its invocations.
//    This information should be output to a file named runtimes.csv in comma-separated
//    values format (one line for each method).

public aspect Graph {
	/**
	 * A pair data structure for keeping track of histograms
	 *
	 * @param <PairA> The type of the first element
	 * @param <PairB> The type of the second element
	 */
	public class Pair<PairA, PairB> {
		public PairA a;
		public PairB b;
		
		public Pair(PairA a, PairB b) {
			this.a = a;
			this.b = b;
		}
		
		@Override
		public String toString() {
			return "[" + this.a + ", " + this.b + "]";
		}
	}
	
	// Define each pointcut used, for cleaner code.
	pointcut any():     call(* **.*()); // Matches any call, anywhere.
	pointcut main():    execution(public static void main(String[])) && !cflowbelow(any()); // Matches the original main method.
	pointcut entryex(): call(public * q3..*(int) throws Exception) && !within(q3..*); // Matches the entry into anything in q3 that throws exceptions.
	pointcut entry():   call(public * q3..*(int)) && !within(q3..*) && !entryex(); // Matches the entry into anything in q3 that doesn't.
	pointcut cut():     cflowbelow(entry()) && call(* q3..*(int)); // Any valid call below an entry point.
	
	// Writers for tracing.
	PrintWriter histogramWriter;
	PrintWriter failureWriter;
	PrintWriter runtimeWriter;
	
	// Stack for keeping track
	Stack<Signature> signatureTrace = new Stack<>();
	
	// Data storage
	Map<Integer, Pair<Integer, Integer>> histogram = new HashMap<>(); // a:input, b:output
	Map<JoinPoint.StaticPart, Integer> successes = new HashMap<>();
	Map<JoinPoint.StaticPart, Integer> failures = new HashMap<>();
	Map<JoinPoint.StaticPart, List<Long>> runtimes = new HashMap<>();
	
	/**
	 * Nicely format the JoinPoint according to the specification, stripping out the return type.
	 * @param join The JoinPoint.
	 * @return The formatted String.
	 */
	public String formatJoin(JoinPoint.StaticPart join) {
		return join == null ? null : join.getSignature().toString().replaceFirst("^[^\\s]*\\s+[^.]+\\.", "");
	}
	
	/**
	 * Check for equality as Signature doesn't implement Comparable; it must be defined.
	 * @param a The first Signature.
	 * @param b The second Signature.
	 * @return True if identical (bar hashcode()), false if not.
	 */
	public boolean compareSignatures(Signature a, Signature b) {
		return a != null & b != null &&
			a.getDeclaringType() == b.getDeclaringType() &&
			a.getDeclaringTypeName() == b.getDeclaringTypeName() &&
			a.getModifiers() == b.getModifiers() &&
			a.getName() == b.getName() &&
			a.toLongString().equals(b.toLongString());
	}
	
	/**
	 * Compute the mean
	 * @param list A list of values
	 * @return The mean
	 */
	public <T> double mean(List<T> list) {
		OptionalDouble optional = list.stream().mapToDouble(l -> ((Number) l).doubleValue()).average();
		return optional.isPresent() ? optional.getAsDouble() : 0.0;
	}
	
	/**
	 * Compute the standard deviation
	 * @param list A list of values
	 * @return The standard deviation
	 */
	public <T> double stdev(List<T> list) {
		if(list.size() == 0) return 0.0;
		double mean = mean(list);
		double distance = list.stream().mapToDouble(l -> Math.pow(((Number) l).doubleValue() - mean, 2)).sum();
		return Math.sqrt(distance / list.size());
	}
	
	/**
	 * Wrap the original main class call to initialise and cleanup the PrintWriters.
	 * @param args Command line arguments.
	 */
	void around(String[] args): main() && args(args) {
		// Open files for tracing.
		try {
			this.failureWriter = new PrintWriter("failures.csv");
			this.runtimeWriter = new PrintWriter("runtimes.csv");
		} catch (IOException e) {
			System.err.println("Failed to open files for tracing! Execution will continue, but with tracing disabled.");
			e.printStackTrace();
		}
		
		proceed(args);
		
		// Write failures
		for(JoinPoint.StaticPart key : this.failures.keySet()) {
			this.failureWriter.append(formatJoin(key) + ", " + (100.0 * this.failures.get(key) / (this.successes.get(key) + this.failures.get(key))) + "%\n");
		}
		
		// Write runtimes
		for(Map.Entry<JoinPoint.StaticPart, List<Long>> entry : this.runtimes.entrySet()) {
			// In nanoseconds!
			this.runtimeWriter.append(formatJoin(entry.getKey()) + ", " + this.mean(entry.getValue()) + ", " + this.stdev(entry.getValue()) + "\n");
		}
		
		this.failureWriter.close();
		this.runtimeWriter.close();
	}
	
	/**
	 * For each entry point, start tracing.
	 * @param i An integer.
	 * @return An integer.
	 */
	int around(int i): entry() && args(i) {
		PrintWriter histogramWriter = null;
		try {
			histogramWriter = new PrintWriter(formatJoin(thisJoinPointStaticPart) + "-hist.csv");
		} catch (IOException e) {
			System.err.println("Failed to open files for tracing! Execution will continue, but with tracing disabled.");
			e.printStackTrace();
		}

		this.histogram = new HashMap<>();
		
		// Update lastSignature to match method, and write the first node called.
		this.signatureTrace = new Stack<>();
		this.signatureTrace.push(thisJoinPointStaticPart.getSignature());

		if(!this.failures.containsKey(thisJoinPointStaticPart) || !this.successes.containsKey(thisJoinPointStaticPart)) {
			this.failures.put(thisJoinPointStaticPart, 0);
			this.successes.put(thisJoinPointStaticPart, 0);
		}
		
		// Compute runtime
		if(!this.runtimes.containsKey(thisJoinPointStaticPart)) this.runtimes.put(thisJoinPointStaticPart, new ArrayList<>());
		long start = System.nanoTime();
		int result = proceed(i);
		long end = System.nanoTime();
		this.runtimes.get(thisJoinPointStaticPart).add(end - start);

		// Success!
		this.successes.put(thisJoinPointStaticPart, this.failures.get(thisJoinPointStaticPart) + 1);
		
		// Write histograms
		for(Map.Entry<Integer, Pair<Integer, Integer>> entry : this.histogram.entrySet()) {
			histogramWriter.append(entry.getKey() + ", " + entry.getValue().a + ", " + entry.getValue().b + "\n");
		}
		
		if(histogramWriter != null) histogramWriter.close();
		
		return result;
	}

	/**
	 * For each entry point that throws exceptions, start tracing.
	 * @param i An integer.
	 * @return An integer.
	 */
	int around(int i) throws Exception: entryex() && args(i) {
		PrintWriter histogramWriter = null;
		try {
			histogramWriter = new PrintWriter(formatJoin(thisJoinPointStaticPart) + "-hist.csv");
		} catch (IOException e) {
			System.err.println("Failed to open files for tracing! Execution will continue, but with tracing disabled.");
			e.printStackTrace();
		}
		
		this.histogram = new HashMap<>();
		
		// Update lastSignature to match method, and write the first node called.
		this.signatureTrace = new Stack<>();
		this.signatureTrace.push(thisJoinPointStaticPart.getSignature());

		if(!this.failures.containsKey(thisJoinPointStaticPart) || !this.successes.containsKey(thisJoinPointStaticPart)) {
			this.failures.put(thisJoinPointStaticPart, 0);
			this.successes.put(thisJoinPointStaticPart, 0);
		}
		
		try {
			// Compute runtime
			if(!this.runtimes.containsKey(thisJoinPointStaticPart)) this.runtimes.put(thisJoinPointStaticPart, new ArrayList<>());
			long start = System.nanoTime();
			int result = proceed(i);
			long end = System.nanoTime();
			this.runtimes.get(thisJoinPointStaticPart).add(end - start);

			// Success!
			this.successes.put(thisJoinPointStaticPart, this.failures.get(thisJoinPointStaticPart) + 1);

			return result;
		} catch(Exception e) {
			// Nope.
			this.failures.put(thisJoinPointStaticPart, this.failures.get(thisJoinPointStaticPart) + 1);
			throw e;
		} finally {
			// Write histograms
			for(Map.Entry<Integer, Pair<Integer, Integer>> entry : this.histogram.entrySet()) {
				histogramWriter.append(entry.getKey() + ", " + entry.getValue().a + ", " + entry.getValue().b + "\n");
			}
			
			if(histogramWriter != null) histogramWriter.close();
		}
	}
	
	/**
	 * Validate each cut, then add it to the list.
	 */
	before(int i): cut() && args(i) {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatureTrace.peek(), thisEnclosingJoinPointStaticPart.getSignature())) {
			this.signatureTrace.push(thisJoinPointStaticPart.getSignature());
			
			// Update histogram input
			if(!this.histogram.containsKey(i)) this.histogram.put(i, new Pair<Integer, Integer>(0, 0));
			this.histogram.get(i).a++;
			
			// Ensure that call key exists to avoid exceptions
			if(!this.failures.containsKey(thisJoinPointStaticPart) || !this.successes.containsKey(thisJoinPointStaticPart)) {
				this.failures.put(thisJoinPointStaticPart, 0);
				this.successes.put(thisJoinPointStaticPart, 0);
			}
		}
	}
	
	after() returning(int i): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatureTrace.peek(), thisJoinPointStaticPart.getSignature())) {
			this.signatureTrace.pop();

			// Update histogram output
			if(!this.histogram.containsKey(i)) this.histogram.put(i, new Pair<Integer, Integer>(0, 0));
			this.histogram.get(i).b++;
			
			this.failures.put(thisJoinPointStaticPart, this.failures.get(thisJoinPointStaticPart) + 1);
		}
	}
	
	after() throwing(Exception e): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatureTrace.peek(), thisJoinPointStaticPart.getSignature())) {
			this.signatureTrace.pop();
			
			this.successes.put(thisJoinPointStaticPart, this.failures.get(thisJoinPointStaticPart) + 1);
		}
	}
}
