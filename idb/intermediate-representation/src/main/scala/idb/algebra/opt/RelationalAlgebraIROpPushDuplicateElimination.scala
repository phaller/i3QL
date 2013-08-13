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
package idb.algebra.opt

import scala.virtualization.lms.common._
import idb.algebra.ir.RelationalAlgebraIRBasicOperators
import idb.lms.extensions.FunctionUtils
import idb.lms.extensions.functions.FunctionsExpDynamicLambda

/**
 * Simplification rules remove operators that reduce to trivial meanings.
 * For example: a ∩ a = a
 *
 * @author Ralf Mitschke
 *
 */
trait RelationalAlgebraIROpPushDuplicateElimination
    extends RelationalAlgebraIRBasicOperators
    with BaseFatExp
    with TupledFunctionsExp
    with FunctionsExpDynamicLambda
    with FunctionUtils
{

    private def returnsParameterAtIndex[Domain, Range] (function: Rep[Domain => Range]): Int = {
        function match {

            case Def (Lambda (_, UnboxedTuple (List (a, b)), Block (body)))
                if body == a => 0
            case Def (Lambda (_, UnboxedTuple (List (a, b)), Block (body)))
                if body == b => 1

            case Def (Lambda (_, UnboxedTuple (List (a, b, c)), Block (body)))
                if body == a => 0
            case Def (Lambda (_, UnboxedTuple (List (a, b, c)), Block (body)))
                if body == b => 1
            case Def (Lambda (_, UnboxedTuple (List (a, b, c)), Block (body)))
                if body == c => 2

            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d)), Block (body)))
                if body == a => 0
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d)), Block (body)))
                if body == b => 1
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d)), Block (body)))
                if body == c => 2
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d)), Block (body)))
                if body == d => 3

            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d, e)), Block (body)))
                if body == a => 0
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d, e)), Block (body)))
                if body == b => 1
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d, e)), Block (body)))
                if body == c => 2
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d, e)), Block (body)))
                if body == d => 3
            case Def (Lambda (_, UnboxedTuple (List (a, b, c, d, e)), Block (body)))
                if body == e => 4

            case Def (Lambda (_, x, Block (body)))
                if body == x => 0

            case _ => -1
        }
    }

    override def duplicateElimination[Domain: Manifest] (
        relation: Rep[Query[Domain]]
    ): Rep[Query[Domain]] =
        (relation match {

            //
            // TODO, why can I not pattern match the cross product?
            case Def (Projection (Def (x: CrossProduct[Any@unchecked, Any@unchecked]), f)) => {
                val bodyIsParameterAtIndex = returnsParameterAtIndex (f)
                bodyIsParameterAtIndex match {
                    case -1 => super.duplicateElimination (relation)
                    case 0 => duplicateElimination (x.relationA)(domainOf (x.relationA))
                    case 1 => duplicateElimination (x.relationB)(domainOf (x.relationB))
                    case _ =>
                        throw new IllegalStateException (
                            "Expected a binary function as projection after cross product, " +
                                "but found more parameters" + f)
                }
            }

            //
            /*
        case Def (Projection (Def (EquiJoin (a, b, l)), f)) if l.size <= 5 => {
            val bodyIsParameterAtIndex = returnsParameterAtIndex (f)
            bodyIsParameterAtIndex match {
                case -1 =>
                    super.duplicateElimination (relation)
                case 0 =>
                    equiJoin (
                        duplicateElimination (a),
                        duplicateElimination (
                            projection (b, convertEqualitiesToProjectedTuple (l, _._2))
                        ),
                        convertEqualitiesToTupleEqualitiesOnSecond (l)
                    )
                case 1 =>
                    equiJoin (
                        duplicateElimination (
                            projection (a, convertEqualitiesToProjectedTuple (l, _._1))
                        ),
                        duplicateElimination (b),
                        convertEqualitiesToTupleEqualitiesOnFirst (l)
                    )
                case _ =>
                    throw new IllegalStateException (
                        "Expected a binary function as projection after equi join, " +
                            "but found more parameters" + f)
            }
        }
            */
        }).asInstanceOf[Rep[Query[Domain]]]

    /*
        // takes a list of equalities, selects the first or second equality function via selector and
        // converts the selected functions into a projection from the Domain to a tuple
        private def convertEqualitiesToProjectedTuple[DomainA, DomainB] (
            equalities: List[(Rep[DomainA => Any], Rep[DomainB => Any])],
            selector: ((Rep[DomainA => Any], Rep[DomainB => Any])) => Rep[Any => Any]
        ): Rep[Any => Any] = {
            equalities.map (selector) match {
                case List (f) => f
                    /*
                case List (f1, f2) =>
                    dynamicLambda(parameter(f1), make_tuple2(body(f1), body(f2)))
                case List (f1, f2, f3) =>
                    dynamicLambda(parameter(f1), make_tuple3(body(f1), body(f2), body(f3)))
                case List (f1, f2, f3, f4) =>
                    dynamicLambda(parameter(f1), make_tuple4(body(f1), body(f2), body(f3), body(f4)))
                    */
                case _ => throw new UnsupportedOperationException
            }
        }


        private def convertEqualitiesToTupleEqualitiesOnSecond[DomainA, DomainB] (
            equalities: List[(Rep[DomainA => Any], Rep[DomainB => Any])]
        ): List[(Rep[DomainA => Any], Rep[Any => Any])] = {
            equalities match {
                case List ((fa, _)) => List((fa, fun((x:Rep[Any]) => x)))
                /*
            case List (f1, f2) =>
                dynamicLambda(parameter(f1), make_tuple2(body(f1), body(f2)))
            case List (f1, f2, f3) =>
                dynamicLambda(parameter(f1), make_tuple3(body(f1), body(f2), body(f3)))
            case List (f1, f2, f3, f4) =>
                dynamicLambda(parameter(f1), make_tuple4(body(f1), body(f2), body(f3), body(f4)))
                */
                case _ => throw new UnsupportedOperationException
            }
        }

        private def convertEqualitiesToTupleEqualitiesOnFirst[DomainA, DomainB] (
            equalities: List[(Rep[DomainA => Any], Rep[DomainB => Any])]
        ): List[(Rep[Any => Any], Rep[DomainB => Any])] = {
            equalities match {
                case List ((_, fb)) => List((fun((x:Rep[Any]) => x), fb))
                /*
            case List (f1, f2) =>
                dynamicLambda(parameter(f1), make_tuple2(body(f1), body(f2)))
            case List (f1, f2, f3) =>
                dynamicLambda(parameter(f1), make_tuple3(body(f1), body(f2), body(f3)))
            case List (f1, f2, f3, f4) =>
                dynamicLambda(parameter(f1), make_tuple4(body(f1), body(f2), body(f3), body(f4)))
                */
                case _ => throw new UnsupportedOperationException
            }
        }
      */
}

