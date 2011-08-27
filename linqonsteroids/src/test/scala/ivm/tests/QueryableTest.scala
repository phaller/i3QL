package ivm
package tests

import expressiontree._

import org.scalatest.junit.JUnitSuite
import org.scalatest.junit.ShouldMatchersForJUnit
import org.junit.Test

import collections.{IncHashSet, IncArrayBuffer}
import collection.mutable.{HashSet, ArrayBuffer}

class QueryableTest extends JUnitSuite with ShouldMatchersForJUnit {
  import Lifting._

  @Test
  def emptyIncHashSet() {
    val a = IncHashSet.empty
    a should not be (null)
    val b = IncHashSet()
    b should not be (null)
    b should be (a)
  }

  @Test
  def builderIncHashSet() {
    val c = IncHashSet.newBuilder[Int]
    c ++= Seq(1, 2, 3)
    val cRes: IncHashSet[Int] = c.result()
    val cRes2 = c.result()
    cRes should be (cRes2)
    cRes.getClass() should be (cRes2.getClass())
    cRes should be (Set(1, 2, 3))
    val d = IncHashSet(1, 2, 3)
    d should be (cRes)
  }

  @Test
  def emptyIncArrayBuffer() {
    val a = IncArrayBuffer.empty
    a should not be (null)
    val b = IncArrayBuffer()
    b should not be (null)
    b should be (a)
  }

  @Test
  def builderIncArrayBuffer() {
    val c = IncArrayBuffer.newBuilder[Int]
    c ++= Seq(1, 2, 3)
    val cRes: IncArrayBuffer[Int] = c.result()
    val cRes2 = c.result()
    cRes should be (cRes2)
    cRes should be (Seq(1, 2, 3))
    val d = IncArrayBuffer(1, 2, 3)
    d should be (cRes)
  }

  @Test
  def testQueryable() {
    val v = new IncArrayBuffer[Int]
    v ++= Seq(1, 2, 3)

    println("v: " + v)
    val vPlusOne: IncArrayBuffer[Int] = v.map(_ + 1) // confusingly, this works
    val vQueryable: QueryReifier[Int] = v.asQueryable
    assert(vQueryable == v)
    //val vQueryablePlusOne2: ArrayBuffer[Int] = vQueryable.map((i: Int) => i + 1) //gives error
    val vQueryablePlusOne: QueryReifier[Int] = vQueryable.map(_ + 1)
    v ++= Seq(4, 5, 6) // Now, vPlusOne should be updated, shouldn't it?

    println("vQueryable: " + vQueryable)
    println("vPlusOne: " + vPlusOne)
    println("vQueryablePlusOne: " + vQueryablePlusOne)
    println("vQueryablePlusOne.interpret.exec(): " + vQueryablePlusOne.interpret.exec())

    val vColl: ArrayBuffer[Int] = v.asCollection
    println("vColl: " + vColl)
    assert(vColl == v)
    val vCollPlusOne: ArrayBuffer[Int] = vColl.map(_ + 1)
    println("vCollPlusOne: " + vCollPlusOne)
  }

  def show[T: Ordering](name: String, v: IncrementalResult[T]) {
    println()
    println("%s: after sorting\t\t%s, before\t\t%s" format(name, v.toSeq.sorted, v))
    //println("vIncUpd.exec(): " + vIncUpd.exec())
    //println("vIncUpd.interpret.exec(): " + vIncUpd.interpret.exec())
    v.exec() should be (v.interpret().exec())
    v.exec() should be (v.inner.exec())
    //println("vIncUpd.inner.exec(): " + vIncUpd.inner.exec())
  }

  @Test
  def testIncremental() {
    val v = new IncHashSet[Int]
    v ++= Seq(1, 2, 3)

    println("v: " + v)
    val vPlusOne: IncHashSet[Int] = v.map(_ + 1) //canBuildFrom gives us the expected return type

    val vIncUpd = new IncrementalResult[Int](v)
    val v2: Queryable[Int, HashSet[Int]] = v //Queryable does not inherit from Traversable!
    println("v2.map(_ + 1): " + v2.map(_ + 1))
    println("v2.asQueryable.map(_ + 1): " + v2.asQueryable.map(_ + 1))
    println("v2.asCollection.map(_ + 1): " + v2.asCollection.map(_ + 1))
    val vQueryable: QueryReifier[Int] = v.asQueryable
    assert(vQueryable == v)
    //val vQueryablePlusOne2: HashSet[Int] = vQueryable.map((i: Int) => i + 1) //gives error
    val vQueryablePlusOne: QueryReifier[Int] = vQueryable.map(_ + 1)
    //val vIncUpdPlus2 = new IncrementalResult(for (i <- vIncUpd.asQueryable) yield 2 * i) //XXX can't use *, not defined, nor asQueryable.
    val vIncUpdPlus2 = new IncrementalResult(for (i <- vIncUpd.asQueryable) yield 2 + i)

    def out() {
      show("vIncUpd", vIncUpd)
      show("vIncUpdPlus2", vIncUpdPlus2)
    }
    out()
    v ++= Seq(4, 5, 6)
    out()

    // Check that redundant updates are handled correctly.
    // test actually - we need an union
    // operation for a proper test.
    v ++= Seq(4, 5, 6) //Now the inclusion count should be 1, not 2!
    out()
    v --= Seq(4, 5, 6) //Now the elements should already be removed!
    out()
    v --= Seq(4, 5, 6)
    out()
    v.clear()
    out()
    v ++= Seq(1, 5, 7)
    out()

    println("vQueryable: " + vQueryable)

    println("vPlusOne: " + vPlusOne)
    println("vQueryablePlusOne: " + vQueryablePlusOne)
    println("vQueryablePlusOne.interpret().exec(): " + vQueryablePlusOne.interpret().exec())

    val vColl: HashSet[Int] = v.asCollection //This is a simple upcast...
    println("vColl: " + vColl)
    assert(vColl == v)
    val vCollPlusOne: HashSet[Int] = vColl.map(_ + 1) //Here, the resulting object has actually HashSet as dynamic type.
    //Since vColl has a different static type, a different implicit is passed here.
    println("vCollPlusOne: %s, type: %s" format (vCollPlusOne, vCollPlusOne.getClass.getName))
  }
}
