//package predicates;

import static saere.term.Terms.atomic;
import static saere.term.Terms.compoundTerm;
import predicates.integers3Factory;
import predicates.primes2Factory;
import predicates.remove3Factory;
import predicates.sift2Factory;
import saere.Goal;
import saere.PredicateRegistry;
import saere.Variable;

public class MainPrimes {

	static {
		PredicateRegistry registry = PredicateRegistry.predicateRegistry();
		primes2Factory.registerWithPredicateRegistry(registry);
		integers3Factory.registerWithPredicateRegistry(registry);
		sift2Factory.registerWithPredicateRegistry(registry);
		remove3Factory.registerWithPredicateRegistry(registry);
	}

	public static void main(String[] args) throws Exception {

		System.out.println("Warm up...(~ 1 Minute)");
		{
			long startTime = System.nanoTime();
			do {
				Variable solution = new Variable();
				Goal s = compoundTerm(atomic("primes"), atomic(1000), solution).call();
				if (!s.next()) {
					throw new Error("Evaluation failed.");
				}
			} while ((System.nanoTime() - startTime) < 60l * 1000l * 1000l * 1000l);
			long duration = System.nanoTime() - startTime;
			System.out.printf("%7.4f\n", new Double(duration / 1000.0 / 1000.0 / 1000.0));
		}

		// System.out.println("Waiting for five seconds...");
		// Thread.sleep(5000);

		Thread t = new Thread(new Runnable() {
			public void run() {

				long startTime = System.nanoTime();
				for (int i = 1; i <= 10; i++) {
					Variable solution = new Variable();
					Goal s = compoundTerm(atomic("time"),
							compoundTerm(atomic("primes"), atomic(1000), solution)).call();
					if (s.next()) {
						System.out.println(" ; " + i + " => " + solution.toProlog());
					} else {
						throw new Error("Evaluation failed.");
					}
				}
				long duration = System.nanoTime() - startTime;
				Double time = new Double(duration / 1000.0 / 1000.0 / 1000.0);
				System.out.printf("%7.4f", time);
				All.writeToPerformanceLog("primes finished in: " + time + "\n");
			}
		});
		t.start();
		t.join();
	}

}
