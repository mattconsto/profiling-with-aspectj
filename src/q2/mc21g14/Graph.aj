package q2.mc21g14;

import java.io.*;
import java.util.*;
import org.aspectj.lang.*;

// Write an aspect that refines your solution to Part 1 (where package name q1 is replaced throughout by
// q2) by not providing an arc from mi to mj if mj throws an exception instance of
// java.lang.Exception when called within the definition of mi.
// Edges should still be included for any method call that terminates normally, even if a later call to the
// same method throws an exception. 

public aspect Graph {
	/**
	 * A helper class that stores the signature, list of edges, and list of nodes.
	 * A stack, or chain, of signatures is required to avoid providing output for example A.
	 * Storing the edges and nodes at each level allows for rolling back changes after an exception occurs.
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
	pointcut any():     call(* *()); // Matches any call, anywhere.
	pointcut main():    execution(public static void main(String[])) && !cflowbelow(any()); // Matches the original main method.
	pointcut entryex(): call(public * q2..*(int) throws Exception) && (!within(q2..*) || (within(q2..*) && main())); // Matches the entry into anything in q2 that throws exceptions.
	pointcut entry():   call(public * q2..*(int)) && (!within(q2..*) || (within(q2..*) && main())) && !entryex(); // Matches the entry into anything in q2 that doesn't.
	pointcut cut():     (cflowbelow(entry()) || cflowbelow(entryex())) && call(* q2..*(int)); // Any valid call below an entry point.
	
	// Writers for tracing.
	protected PrintWriter edgeWriter;
	protected PrintWriter nodeWriter;
	
	// Stack for keeping track
	protected Stack<Trace> stackTrace = new Stack<>();
	
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
			this.edgeWriter = new PrintWriter("q2-edges.csv");
			this.nodeWriter = new PrintWriter("q2-nodes.csv");
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
	 * This is necessary as if an exception can be thrown, it needs to be handled differently so that it is able to re-throw the exception.
	 * Because of a "circular advice precedence" error, this unfortunately cannot be split up into before()/after() pointcuts and handled separately.
	 * @param i An integer.
	 * @return An integer.
	 */
	int around(int i): entry() && args(i) {
		// Update lastSignature to match method, and write the first node called.
		this.stackTrace = new Stack<>();
		this.stackTrace.push(new Trace(thisJoinPointStaticPart.getSignature(), "", formatJoin(thisJoinPointStaticPart) + "\n"));

		int result = proceed(i);
		
		// Once finished, append the line to the writers.
		this.edgeWriter.append(this.stackTrace.peek().edges);
		this.nodeWriter.append(this.stackTrace.peek().nodes);
		
		return result;
	}

	/**
	 * For each entry point that throws exceptions, start tracing.
	 * This is necessary as if an exception can be thrown, it needs to be handled differently so that it is able to re-throw the exception.
	 * Because of a "circular advice precedence" error, this unfortunately cannot be split up into before()/after() pointcuts and handled separately.
	 * @param i An integer.
	 * @return An integer.
	 */
	int around(int i) throws Exception: entryex() && args(i) {
		// Update lastSignature to match method, and write the first node called.
		this.stackTrace = new Stack<>();
		this.stackTrace.push(new Trace(thisJoinPointStaticPart.getSignature(), "", formatJoin(thisJoinPointStaticPart) + "\n"));
		
		try {
			int result = proceed(i);

			// Once finished, append the line to the writers.
			this.edgeWriter.append(this.stackTrace.peek().edges);
			this.nodeWriter.append(this.stackTrace.peek().nodes);
			
			return result;
		} catch(Exception e) {
			throw e;
		}
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
			
			// Push to the stack
			this.stackTrace.push(new Trace(thisJoinPointStaticPart.getSignature(), 
				this.stackTrace.peek().edges + source + " -> " + target + "\n",
				this.stackTrace.peek().nodes + target + "\n"
			));
		}
	}
	
	/**
	 * On success
	 * @param i The return value
	 */
	after() returning(int i): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.stackTrace.peek().signature, thisJoinPointStaticPart.getSignature())) {
			// Move the last element up the stack, keeping the parent signature intact
			Trace item = this.stackTrace.pop();
			Signature signature = this.stackTrace.pop().signature;
			this.stackTrace.push(new Trace(signature, item.edges, item.nodes));
		}
	}
	
	/**
	 * On failure
	 * @param e The exception
	 */
	after() throwing(Exception e): cut() {
		// Check that the call is called by the last call (Hopefully that makes sense).
		if(compareSignatures(this.stackTrace.peek().signature, thisJoinPointStaticPart.getSignature())) {
			// This call failed, so the results are discarded.
			this.stackTrace.pop();
		}
	}
}
