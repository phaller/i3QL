package collection.incremental;

/**
 * @author Ralf Mitschke
 */
public class OrderedIntList {
    public IntListElem head;
    public boolean doInvariants = true;
    public int realsum;

    public OrderedIntList() {
        head = null;
    }

    private ListOrderingInvariantAsRecursive orderingInvariant = new ListOrderingInvariantAsRecursive();

    public boolean isOrdered() {
        return orderingInvariant.unorderedElements().size() == 0;
    }

    public Integer sum(IntListElem n) {
        if (n == null)
            return 0;
        return n.value + sum(n.next);
    }

    public int size() {
        int s = 0;
        for (IntListElem i = head; i != null; i = i.next) s++;
        return s;
    }

    public void invariants() {
        //System.out.println("list is now " + this);
        if (doInvariants) {
            if (!isOrdered()) {
                System.out.println("List is not ordered!");
                System.exit(1);
            }
//			int s = sum(head);
//			if (s != realsum) {
//				System.out.println("Computed sum " + s + " differs from real sum " + realsum);
//				System.exit(1);
//			}

        }
        // System.out.println("Invariant count is " + InvCount);
    }

    public int shift() {
        invariants();
        //System.out.println("Shifting...");
        if (head == null) {
            //System.out.println("WTF?");
            invariants();
            return 0;
        }
        orderingInvariant.elements().remove(head);
        IntListElem n = head;
        head = head.next;
//		realsum -= n.value;
        invariants();
        return n.value;
    }

    // removes a single element with value a
    public void remove(int a) {
        invariants();
        //System.out.println("Removing " + a);
        IntListElem n = head;
        if (n != null && n.value == a) {
            orderingInvariant.elements().remove(head);
            head = n.next;
            orderingInvariant.elements().add(head);
//			realsum -= n.value;
            invariants();
            return;
        }
        while (n != null && n.next != null && n.next.value < a) {
            n = n.next;
        }

        if (n != null && n.next != null && n.next.value == a) {
            //realsum -= n.next.value;
            orderingInvariant.elements().remove(n);
            n.next = n.next.next;
            orderingInvariant.elements().add(n);
        }
        invariants();
    }

    // inserts while preserving order
    public void insert(int a) {
        //System.out.println("Top invariants");
        invariants();
        //realsum += a;
        //System.out.println("Inserting " + a);
        IntListElem nw = new IntListElem(a);
        orderingInvariant.elements().add(nw);
        if (head == null || head.value >= a) {
            if (head != null) {
                orderingInvariant.elements().remove(nw);
                nw.next = head;
                orderingInvariant.elements().add(nw);
            }
            head = nw;

            invariants();
            return;
        }
        IntListElem n = head;
        while (n != null && n.next != null && n.next.value < a)
            n = n.next;

        orderingInvariant.elements().remove(nw);
        nw.next = n.next;
        orderingInvariant.elements().add(nw);

        orderingInvariant.elements().remove(n);
        n.next = nw;
        orderingInvariant.elements().add(n);

        //System.out.println("Invariants at bottom");
        invariants();
    }

    public void barf() {
        invariants();
        System.out.println("About to barf!");
        head.value = head.next.value + 1;
        invariants();
    }

    public String toString() {
        StringBuffer b = new StringBuffer("[ ");
        IntListElem m = head;
        while (m != null) {
            b.append(m.value + " ");
            m = m.next;
        }
        b.append("]");
        return b.toString();
    }

    public boolean hasElements() {
        return head != null;
    }

}
