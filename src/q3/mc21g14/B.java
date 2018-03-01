package q3.mc21g14;

public class B {
	public int foo(int a) {
		bar(1);
		return 0;
	}

	public int bar(int b) {
		return baz(b);
	}

	public int baz(int a) {
		return a + a;
	}
	
	public int sdf(int a) throws Exception {
		bar(a + 1);
		try {
			fail(2);
		} catch(Exception ignored) {}
		fail(4);
		return baz(a);
	}
	
	public int fail(int a) throws Exception {
		throw new Exception("Nope");
	}

	public int sdff(int a) {
		bar(a + 1);
		try {
			fail(2);
		} catch(Exception ignored) {}
		return baz(a);
	}
}