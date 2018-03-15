package q3.mc21g14;

import java.io.*;
import java.util.*;
import org.aspectj.lang.*;

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
		
		public Pair(PairA a, PairB b) {this.a = a; this.b = b;}
		@Override
		public String toString() {return "[" + this.a + ", " + this.b + "]";}
	}
	
	// Define each pointcut used, for cleaner code.
	pointcut any():     call(* **.*()); // Matches any call, anywhere.
	pointcut main():    execution(public static void main(String[])) && !cflowbelow(any()); // Matches the original main method.
	pointcut entryex(): call(public * q3..*(int) throws Exception) && (!within(q3..*) || (within(q3..*) && main())); // Matches the entry into anything in q3 that throws exceptions.
	pointcut entry():   call(public * q3..*(int)) && (!within(q3..*) || (within(q3..*) && main())) && !entryex(); // Matches the entry into anything in q3 that doesn't.
	pointcut cut():     (cflowbelow(entry()) || cflowbelow(entryex())) && call(* q3..*(int)); // Any valid call below an entry point.
	
	// Writers for tracing.
	protected PrintWriter histogramWriter;
	protected PrintWriter failureWriter;
	protected PrintWriter runtimeWriter;
	
	// Stack for keeping track
	protected Stack<Signature> signatureTrace = new Stack<>();
	
	// Data storage
	protected Map<String, Map<Integer, Pair<Integer, Integer>>> histogram = new HashMap<>(); // a:input, b:output
	protected Map<String, Integer> successes = new HashMap<>();
	protected Map<String, Integer> failures = new HashMap<>();
	protected Map<String, List<Double>> runtimes = new HashMap<>();
	
	/**
	 * Nicely format the JoinPoint according to the specification, stripping out the return type.
	 * @param join The JoinPoint.
	 * @return The formatted String.
	 */
	public String formatJoin(JoinPoint.StaticPart join) {
		return join == null ? null : formatJoin(join.getSignature());
	}
	public String formatJoin(Signature sig) {
		return sig == null ? null : sig.toString().replaceFirst("^[^\\s]*\\s+", "");
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
		return list.stream().mapToDouble(l -> ((Number) l).doubleValue()).average().orElse(0);
	}
	
	/**
	 * Compute the standard deviation
	 * @param list A list of values
	 * @return The standard deviation
	 */
	public <T> double stdev(List<T> list) {
		if(list.size() == 0) return 0.0;
		double mean = mean(list);
		return Math.sqrt(list.stream().mapToDouble(l -> Math.pow(((Number) l).doubleValue() - mean, 2)).sum() / list.size());
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
		for(String key : this.failures.keySet()) {
			this.failureWriter.append(key + ", " + (100.0 * this.failures.get(key) / (this.successes.get(key) + this.failures.get(key))) + "%\n");
		}
		
		// Write runtimes
		for(Map.Entry<String, List<Double>> entry : this.runtimes.entrySet()) {
			// In milliseconds!
			this.runtimeWriter.append(entry.getKey() + ", " + this.mean(entry.getValue()) + ", " + this.stdev(entry.getValue()) + "\n");
		}

		// Write histograms
		for(Map.Entry<String, Map<Integer, Pair<Integer, Integer>>> entry1 : this.histogram.entrySet()) {
			PrintWriter histogramWriter = null;
			try {
				histogramWriter = new PrintWriter(entry1.getKey() + "-hist.csv");
			} catch (IOException e) {
				System.err.println("Failed to open files for tracing! Execution will continue, but with tracing disabled.");
				e.printStackTrace();
			}

			// Write histograms
			for(Map.Entry<Integer, Pair<Integer, Integer>> entry2 : entry1.getValue().entrySet()) {
				histogramWriter.append(entry2.getKey() + ", " + entry2.getValue().a + ", " + entry2.getValue().b + "\n");
			}
			
			histogramWriter.close();
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
		String key = formatJoin(thisJoinPointStaticPart);
		
		// Update lastSignature to match method, and write the first node called.
		this.signatureTrace = new Stack<>();
		this.signatureTrace.push(thisJoinPointStaticPart.getSignature());

		// If missing, initialise failures/successes
		if(!this.failures.containsKey(key) || !this.successes.containsKey(key)) {
			this.failures.put(key, 0);
			this.successes.put(key, 0);
		}

		// Track histogram input
		if(!this.histogram.containsKey(key)) this.histogram.put(key, new HashMap<Integer, Pair<Integer, Integer>>());
		if(!this.histogram.get(key).containsKey(i)) this.histogram.get(key).put(i, new Pair<Integer, Integer>(0, 0));
		this.histogram.get(key).get(i).a++;
		
		// Compute runtime
		if(!this.runtimes.containsKey(key)) this.runtimes.put(key, new ArrayList<>());
		long start = System.nanoTime();
		int result = proceed(i);
		long end = System.nanoTime();
		this.runtimes.get(key).add((end - start) / 1_000_000.0);
		
		// Track histogram output
		this.histogram.get(key).get(i).b++;

		// Success!
		this.successes.put(key, this.failures.get(key) + 1);
		
		return result;
	}

	/**
	 * For each entry point that throws exceptions, start tracing.
	 * @param i An integer.
	 * @return An integer.
	 */
	int around(int i) throws Exception: entryex() && args(i) {
		String key = formatJoin(thisJoinPointStaticPart);
		
		// Update lastSignature to match method, and write the first node called.
		this.signatureTrace = new Stack<>();
		this.signatureTrace.push(thisJoinPointStaticPart.getSignature());

		// If missing, initialise failures/successes
		if(!this.failures.containsKey(key) || !this.successes.containsKey(key)) {
			this.failures.put(key, 0);
			this.successes.put(key, 0);
		}

		// Track histogram input
		if(!this.histogram.containsKey(key)) this.histogram.put(key, new HashMap<Integer, Pair<Integer, Integer>>());
		if(!this.histogram.get(key).containsKey(i)) this.histogram.get(key).put(i, new Pair<Integer, Integer>(0, 0));
		this.histogram.get(key).get(i).a++;
		
		try {
			// Compute runtime
			if(!this.runtimes.containsKey(key)) this.runtimes.put(key, new ArrayList<>());
			long start = System.nanoTime();
			int result = proceed(i);
			long end = System.nanoTime();
			this.runtimes.get(key).add((end - start) / 1_000_000.0);

			// Success!
			this.successes.put(key, this.failures.get(key) + 1);
			
			// Track histogram output
			this.histogram.get(key).get(i).b++;

			return result;
		} catch(Exception e) {
			// Nope.
			this.failures.put(key, this.failures.get(key) + 1);
			throw e;
		}
	}
	
	/**
	 * Validate each cut, then add it to the list.
	 */
	before(int i): cut() && args(i) {
		Signature sig = thisJoinPointStaticPart.getSignature();
		String key = formatJoin(sig);
		
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatureTrace.peek(), sig)) {
			this.signatureTrace.push(sig);
			
			// Update histogram input
			if(!this.histogram.containsKey(key)) this.histogram.put(key, new HashMap<Integer, Pair<Integer, Integer>>());
			if(!this.histogram.get(key).containsKey(i)) this.histogram.get(key).put(i, new Pair<Integer, Integer>(0, 0));
			this.histogram.get(key).get(i).a++;
			
			// Ensure that call key exists to avoid exceptions
			if(!this.failures.containsKey(key) || !this.successes.containsKey(key)) {
				this.failures.put(key, 0);
				this.successes.put(key, 0);
			}
		}
	}
	
	after() returning(int i): cut() {
		Signature sig = thisJoinPointStaticPart.getSignature();
		String key = formatJoin(sig);
		
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatureTrace.peek(), sig)) {
			this.signatureTrace.pop();

			// Update histogram output
			if(!this.histogram.containsKey(key)) this.histogram.put(key, new HashMap<Integer, Pair<Integer, Integer>>());
			if(!this.histogram.get(key).containsKey(i)) this.histogram.get(key).put(i, new Pair<Integer, Integer>(0, 0));
			this.histogram.get(key).get(i).b++;
			
			this.successes.put(key, this.successes.get(key) + 1);
		}
	}
	
	after() throwing(Exception e): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatureTrace.peek(), thisJoinPointStaticPart.getSignature())) {
			this.signatureTrace.pop();
			
			String key = formatJoin(thisJoinPointStaticPart);
			this.failures.put(key, this.failures.get(key) + 1);
		}
	}
}
