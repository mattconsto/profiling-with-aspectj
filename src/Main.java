public class Main {
	public static void main(String[] args) {
		System.out.println(new q1.mc21g14.A().foo(1));
		System.out.println(new q1.mc21g14.B().foo(2));
		
		System.out.println();
		
		System.out.println(new q2.mc21g14.A().foo(3));
		System.out.println(new q2.mc21g14.B().foo(4));
		try {
			System.out.println(new q2.mc21g14.B().sdf(5));
		} catch (Exception ignored) {}
		System.out.println(new q2.mc21g14.B().sdff(6));

		System.out.println();
		
		System.out.println(new q3.mc21g14.A().foo(3));
		System.out.println(new q3.mc21g14.B().foo(4));
		try {
			System.out.println(new q3.mc21g14.B().sdf(5));
		} catch (Exception ignored) {}
		System.out.println(new q3.mc21g14.B().sdff(6));
	}
}
