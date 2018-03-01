package q1.mc21g14;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.Stack;

import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.Signature;

// Write an aspect that constructs the dynamic call graph
// of a Java program restricted to all public methods 
// that take one argument int, return an int, and are 
// defined in any class within the package called q1 or
// any of the packages within the q1 hierarchy.

public aspect Graph {
	/**
	 * A helper class that stores the signature, list of edges, and list of nodes.
	 */
	public class Trace {
		public Signature signature;
		public String edges;
		public String nodes;
		
		public Trace(Signature signature, String edges, String nodes) {
			this.signature = signature;
			this.edges     = edges;
			this.nodes     = nodes;
		}
	}
	
	// Define each pointcut used, for cleaner code.
	pointcut any():   call(* *(..)); // Matches any call, anywhere.
	pointcut main():  execution(public static void main(String[])) && !cflowbelow(any()); // Matches the original main method.
	pointcut entry(): call(public * q1..*(int)) && !within(q1..*); // Matches the entry into anything in q1.
	pointcut cut():   cflowbelow(entry()) && call(* q1..*(int)); // Any valid call below an entry point.
	
	// Writers for tracing.
	PrintWriter edgeWriter;
	PrintWriter nodeWriter;
	
	// Stack for keeping track
	Stack<Trace> stackTrace = new Stack<>();
	
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
	 * Wrap the original main class call to initialise and cleanup the PrintWriters.
	 * @param args Command line arguments.
	 */
	void around(String[] args): main() && args(args) {
		// Open files for tracing.
		try {
			this.edgeWriter = new PrintWriter("q1-edges.csv");
			this.nodeWriter = new PrintWriter("q1-nodes.csv");
		} catch (IOException e) {
			System.err.println("Failed to open files for tracing! Execution will continue, but with tracing disabled.");
			e.printStackTrace();
		}
		
		proceed(args);
		
		this.edgeWriter.close();
		this.nodeWriter.close();
	}
	
	/**
	 * For each entry point, start tracing.
	 * @param i An integer.
	 * @return An integer.
	 */
	int around(int i): entry() && args(i) {
		// Update lastSignature to match method, and write the first node called.
		this.stackTrace = new Stack<>();
		this.stackTrace.push(new Trace(thisJoinPointStaticPart.getSignature(), "", formatJoin(thisJoinPointStaticPart) + "\n"));

		int result = proceed(i);
		
		this.edgeWriter.append(this.stackTrace.peek().edges);
		this.nodeWriter.append(this.stackTrace.peek().nodes);
		
		return result;
	}
	
	/**
	 * Validate each cut, then add it to the list.
	 */
	before(): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.stackTrace.peek().signature, thisEnclosingJoinPointStaticPart.getSignature())) {
			// Stringify
			String source = formatJoin(thisEnclosingJoinPointStaticPart);
			String target = formatJoin(thisJoinPointStaticPart);
			
			this.stackTrace.push(new Trace(thisJoinPointStaticPart.getSignature(), 
				this.stackTrace.peek().edges + source + " -> " + target + "\n", 
				this.stackTrace.peek().nodes + target + "\n"
			));
		}
	}
	
	/**
	 * Update the stack.
	 */
	after(): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.stackTrace.peek().signature, thisJoinPointStaticPart.getSignature())) {
			// Move the last element up the stack, keeping signature intact
			Trace item = this.stackTrace.pop();
			Signature signature = this.stackTrace.pop().signature;
			this.stackTrace.push(new Trace(signature, item.edges, item.nodes));
		}
	}
}
