package q1.mc21g14;

public class A {
	public int foo(int a) {
		bar();
		return 0;
	}

	private void bar() {
		baz(4);
	}

	public int baz(int a) {
		return a + a;
	}
}