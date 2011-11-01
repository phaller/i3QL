package ivm
package opaltests

import expressiontree.{Lifting, Exp}
import Lifting._
import de.tud.cs.st.bat.resolved
import resolved.reader.Java6Framework
import resolved._
import Java6Framework.ClassFile

/**
 * User: pgiarrusso
 * Date: 1/11/2011
 */

class EvalOpalTests {
  import OpalTestData._
  import BATLifting._

  //Translate examples from paper:
  //Michael Eichberg, Sven Kloppenburg, Karl Klose and Mira Mezini,
  //"Defining and Continuous Checking of Structural Program Dependencies", ICSE '08.
  def continuousCheckingPaper() {
    //XXX bug: we should have Set here!
    def sourceElems(Types: Exp[Traversable[ClassFile]]) = Types union (Types flatMap (_.methods)) union (Types flatMap (_.fields))

    //Listing 3:
    val Types = for {
      classFile <- queryData
      if classFile.thisClass.packageName === "bat.type"
    } yield classFile
    val TypesEnsemble = sourceElems(Types)
    val TypesFlyweightFactoryEnsemble = sourceElems(queryData filter (x => x.thisClass.packageName === "bat.type" && x.thisClass.simpleName === "TypeFactory"))
    val tmp = queryData filter (x => x.thisClass.packageName === "bat.type" && x.thisClass.simpleName === "IType")
    val TypesFlyweightCreationEnsemble = for {
      classFile <- queryData
      cf2 <- tmp
      ancestorInterface <- classFile.interfaces
      if ancestorInterface === cf2 //we do need a contains method!
      method <- classFile.methods
    } yield method

    //Listing 5:
    val uses: Exp[Set[(AnyRef, AnyRef)]] = null
    /*
    for {
      el <- uses
      val (s, t) = unliftPair(el)
      t1 <- TypesFlyweightCreationEnsemble
      if t === t1
      //I'm stuck here, since I can't express !(a contains b)
    } yield null
    */
    //Rewrite to avoid using non-working pattern matching, ugly unliftPair and non-working value definitions
    for {
      el <- uses
      t <- TypesFlyweightCreationEnsemble
      if el._2 === t
      //I'm stuck here, since I can't express !(a contains b) yet.
      s <- TypesFlyweightFactoryEnsemble
      if el._1 !== s
    } yield null
  }
}
