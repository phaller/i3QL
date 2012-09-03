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
package sae.syntax.sql.ast

import sae.LazyView
import sae.operators.{Conversions, CrossProduct, SetDuplicateElimination, BagProjection}

/**
 * Created with IntelliJ IDEA.
 * User: Ralf Mitschke
 * Date: 02.09.12
 * Time: 20:57
 */

object Compiler
{
    def apply[Domain <: AnyRef, Range <: AnyRef](whereClause: WhereClause1[Domain, Range]) = null

    def apply[Domain <: AnyRef, Range <: AnyRef](fromClause: FromClause1[Domain, Range]): LazyView[Range] =
    {
        val projection = fromClause.selectClause.projection match {
            case Some (f) => new BagProjection (f, fromClause.relation)
            case None => fromClause.relation.asInstanceOf[LazyView[Range]] // this is made certain by the ast construction
        }
        if (fromClause.selectClause.distinct) {
            new SetDuplicateElimination (projection)
        }
        else
        {
            projection
        }
    }

    def apply[DomainA <: AnyRef, DomainB <: AnyRef, Range <: AnyRef](fromClause: FromClause2[DomainA, DomainB, Range]): LazyView[Range] =
    {
        val crossProduct = new CrossProduct (
            Conversions.lazyViewToMaterializedView (fromClause.relationA),
            Conversions.lazyViewToMaterializedView (fromClause.relationB)
        )

        val projection = fromClause.selectClause.projection match {
            case Some (f) => new BagProjection (
                (tuple: (DomainA, DomainB)) => f (tuple._1, tuple._2),
                crossProduct
            )
            case None => crossProduct.asInstanceOf[LazyView[Range]] // this is made certain by the ast construction
        }
        if (fromClause.selectClause.distinct) {
            new SetDuplicateElimination (projection)
        }
        else
        {
            projection
        }
    }

}
