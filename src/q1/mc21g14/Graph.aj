package q1.mc21g14;

import java.io.*;
import java.util.*;
import org.aspectj.lang.*;

// Write an aspect that constructs the dynamic call graph
// of a Java program restricted to all public methods 
// that take one argument int, return an int, and are 
// defined in any class within the package called q1 or
// any of the packages within the q1 hierarchy.

public aspect Graph {
	// Define each pointcut used, for cleaner code.
	pointcut any():   call(* *(..)); // Matches any call, anywhere.
	pointcut main():  execution(public static void main(String[])) && !cflowbelow(any()); // Matches the original main method.
	pointcut entry(): call(public * q1..*(int)) && (!within(q1..*) || (within(q1..*) && main())); // Matches the entry into anything in q1.
	pointcut cut():   cflowbelow(entry()) && call(* q1..*(int)); // Any valid call below an entry point.
	
	// Writers for tracing.
	protected PrintWriter edgeWriter;
	protected PrintWriter nodeWriter;
	
	// Variables for keeping track
	protected Stack<Signature> signatures = new Stack<>();
	protected String edges;
	protected String nodes;
	
	/**
	 * Nicely format the JoinPoint according to the specification, stripping out the return type.
	 * @param join The JoinPoint.
	 * @return The formatted String.
	 */
	public String formatJoin(JoinPoint.StaticPart join) {
		return join == null ? null : join.getSignature().toString().replaceFirst("^[^\\s]*\\s+", "");
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
		this.signatures = new Stack<>();
		this.signatures.push(thisJoinPointStaticPart.getSignature());
		this.edges = "";
		this.nodes = formatJoin(thisJoinPointStaticPart) + "\n";

		int result = proceed(i);
		
		this.edgeWriter.append(this.edges);
		this.nodeWriter.append(this.nodes);
		
		return result;
	}
	
	/**
	 * Validate each cut, then add it to the list.
	 */
	before(): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatures.peek(), thisEnclosingJoinPointStaticPart.getSignature())) {
			// Stringify
			String source = formatJoin(thisEnclosingJoinPointStaticPart);
			String target = formatJoin(thisJoinPointStaticPart);
			
			this.signatures.push(thisJoinPointStaticPart.getSignature());
			this.edges += source + " -> " + target + "\n"; 
			this.nodes += target + "\n";
		}
	}
	
	/**
	 * Update the stack.
	 */
	after(): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.signatures.peek(), thisJoinPointStaticPart.getSignature())) {
			// Remove the last signature from the stack
			this.signatures.pop();
		}
	}
}
