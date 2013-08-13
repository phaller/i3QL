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
package idb.lms.extensions.equivalence

import scala.virtualization.lms.common.StringOpsExp

/**
 *
 * @author Ralf Mitschke
 *
 */

trait StringOpsExpAlphaEquivalence
    extends StringOpsExp
    with BaseExpAlphaEquivalence
{

    override def isEquivalent[A, B] (a: Exp[A], b: Exp[B])(implicit renamings: VariableRenamings): Boolean =
        (a, b) match {
            case (Def (StringPlus (s1, o1)), Def (StringPlus (s2, o2))) =>
                isEquivalent (s1, s2) &&
                    isEquivalent (o1, o2)

            case (Def (StringStartsWith (s1, starts1)), Def (StringStartsWith (s2, starts2))) =>
                isEquivalent (s1, s2) &&
                    isEquivalent (starts1, starts2)

            case (Def (StringTrim (s1)), Def (StringTrim (s2))) =>
                isEquivalent (s1, s2)

            case (Def (StringSplit (s1, separators1)), Def (StringSplit (s2, separators2))) =>
                isEquivalent (s1, s2) &&
                    isEquivalent (separators1, separators2)

            case (Def (StringValueOf (x1)), Def (StringValueOf (x2))) =>
                isEquivalent (x1, x2)

            case (Def (StringToDouble (s1)), Def (StringToDouble (s2))) =>
                isEquivalent (s1, s2)

            case (Def (StringToFloat (s1)), Def (StringToFloat (s2))) =>
                isEquivalent (s1, s2)

            case (Def (StringToInt (s1)), Def (StringToInt (s2))) =>
                isEquivalent (s1, s2)

            case _ => super.isEquivalent (a, b)
        }

}