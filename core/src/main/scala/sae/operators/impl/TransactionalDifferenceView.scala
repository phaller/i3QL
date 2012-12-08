/* License (BSD Style License):
 *  Copyright (c) 2009, 2011
 *  Software Technology Group
 *  Department of Computer Science
 *  Technische Universität Darmstadt
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *
 *  - Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *  - Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *  - Neither the name of the Software Technology Group or Technische
 *    Universität Darmstadt nor the names of its contributors may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 */
package sae.operators.impl

import sae.operators.Difference
import sae.{Relation, Observable, Observer}
import util.TransactionObserver
import com.google.common.collect.Multiset.Entry

/**
 * The difference operation in our algebra has non-distinct bag semantics
 *
 * This class can compute the difference efficiently by relying on indices from the underlying relations.
 * The operation itself does not store any intermediate results.
 * Updates are computed based on indices and foreach is recomputed on every call.
 *
 *
 * The difference can be update by the expression:
 * [(Δright- ∪ Δleft+) - (Δleft- ∪ Δright+)] - (right - left)
 */
class TransactionalDifferenceView[Domain](val left: Relation[Domain],
                                          val right: Relation[Domain])
    extends Difference[Domain]
{
    left addObserver LeftObserver

    right addObserver RightObserver

    import com.google.common.collect.HashMultiset

    override def isStored = false

    override protected def childObservers(o: Observable[_]): Seq[Observer[_]] = {
        if (o == left) {
            return List (LeftObserver)
        }
        if (o == right) {
            return List (RightObserver)
        }
        Nil
    }

    /**
     * Applies f to all elements of the view.
     */
    def foreach[T](f: (Domain) => T) {
        val leftDiffRight: HashMultiset[Domain] = HashMultiset.create[Domain]()
        val rightDiffLeft: HashMultiset[Domain] = HashMultiset.create[Domain]()
        val intersection: HashMultiset[Domain] = HashMultiset.create[Domain]()
        left.foreach (v => {
            leftDiffRight.add (v)
            intersection.add (v)
        })
        right.foreach (v => rightDiffLeft.add (v))
        intersection.retainAll (rightDiffLeft)
        leftDiffRight.removeAll (intersection)

        val it = leftDiffRight.iterator ()
        while (it.hasNext) {
            val v = it.next ()
            f (v)
        }
    }

    def doDifferenceAndCleanUp() {
        differenceAdditions ()
        differenceDeletions ()
        LeftObserver.clear ()
        RightObserver.clear ()
    }

    private def differenceAdditions() {
        val it: java.util.Iterator[Entry[Domain]] = LeftObserver.additions.entrySet ().iterator ()
        while (it.hasNext) {
            val next = it.next ()
            val left = next.getElement
            val leftCount = next.getCount
            val rightCount = RightObserver.additions.count (left)
            val diff = leftCount - rightCount
            var i = 0
            while (i < diff) {
                element_added (left)
                i += 1
            }
        }
    }

    private def differenceDeletions() {
        // TODO review this
        val it: java.util.Iterator[Entry[Domain]] = LeftObserver.deletions.entrySet ().iterator ()
        while (it.hasNext) {
            val next = it.next ()
            val left = next.getElement
            val leftCount = next.getCount
            val rightCount = RightObserver.deletions.count (left)
            val diff = rightCount - leftCount
            var i = 0
            while (i < diff) {
                element_removed (left)
                i += 1
            }
        }
    }

    var leftFinished  = false
    var rightFinished = false

    object LeftObserver extends TransactionObserver[Domain]
    {
        override def endTransaction() {
            leftFinished = true
            if (rightFinished)
            {
                doDifferenceAndCleanUp ()
                notifyEndTransaction ()
                leftFinished = false
                rightFinished = false
            }
        }
    }

    object RightObserver extends TransactionObserver[Domain]
    {
        override def endTransaction() {
            rightFinished = true
            if (leftFinished)
            {
                doDifferenceAndCleanUp ()
                notifyEndTransaction ()
                leftFinished = false
                rightFinished = false
            }
        }

    }

}