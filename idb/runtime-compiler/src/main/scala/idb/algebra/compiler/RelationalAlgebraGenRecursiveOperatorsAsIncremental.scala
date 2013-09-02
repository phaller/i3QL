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
 *  Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *  Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *  Neither the name of the Software Technology Group or Technische
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
package idb.algebra.compiler

import idb.algebra.ir.{RelationalAlgebraIRRecursiveOperators, RelationalAlgebraIRBasicOperators}
import idb.lms.extensions.CompileScalaExt
import idb.operators.impl._
import scala.virtualization.lms.common.ScalaGenEffect
import scala.virtualization.lms.common.FunctionsExp

/**
 *
 * @author Ralf Mitschke
 */
trait RelationalAlgebraGenRecursiveOperatorsAsIncremental
    extends RelationalAlgebraGenBaseAsIncremental
    with RelationalAlgebraGenQueryCache
    with CompileScalaExt
    with ScalaGenEffect
{

    val IR: RelationalAlgebraIRBasicOperators
        with RelationalAlgebraIRRecursiveOperators
        with RelationalAlgebraGenSAEBinding
        with FunctionsExp

    import IR.Rep
    import IR.Def
    import IR.Query
    import IR.Relation
    import IR.Recursion
    import IR.RecursionResult


    override def compile[Domain] (query: Rep[Query[Domain]]): Relation[Domain] = {
        query match {
            /*
        case Def (e@TransitiveClosure (r, h, t)) => {
            if(e.isIncrementLocal)
                new TransactionalCyclicTransitiveClosureView(
                    compile (r) (e.mEdge),
                    compileFunctionWithDynamicManifests(h),
                    compileFunctionWithDynamicManifests(t),
                    false).asInstanceOf[Relation[Domain]]
            else
                new AcyclicTransitiveClosureView(compile (r) (e.mEdge), compileFunctionWithDynamicManifests(h),
                compileFunctionWithDynamicManifests(t), false).asInstanceOf[Relation[Domain]]
        }*/

            case Def (Recursion (b, Def (RecursionResult (r, _)))) => {
                compile (b)

            }

            case Def (RecursionResult (r, Def(s : Recursion[_]))) => {
                val result = compile (r)
                val base = getRelation (s.base)
                RecursiveDRed (base, result, isSet = false)
            }

            case _ => super.compile (query)
        }
    }

}
