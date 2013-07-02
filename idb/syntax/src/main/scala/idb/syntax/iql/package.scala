package idb.syntax

import idb.syntax.iql.IR._
import scala.language.implicitConversions
import idb.syntax.iql.planning.ClauseToAlgebra
import idb.syntax.iql.compilation.CompilerBinding

/**
 *
 * @author Ralf Mitschke
 *
 */
package object iql
{

    val * : STAR_KEYWORD = impl.StarKeyword

    implicit def extentToQuery[Domain] (ext: Extent[Domain])(
        implicit mDom: Manifest[Domain],
        mExt: Manifest[Extent[Domain]]
    ): Rep[Query[Domain]] = extent (ext)

    implicit def plan[Domain: Manifest, Range: Manifest] (clause: IQL_QUERY[Domain,Range]): Rep[Query[Range]] =
        ClauseToAlgebra (clause)

    implicit def compile[Domain: Manifest,Range: Manifest] (clause: IQL_QUERY[Domain,Range]):Relation[Range] =
        CompilerBinding.compile(plan(clause))

    implicit def funTuple2AsFun[Domain: Manifest, RangeA: Manifest, RangeB: Manifest] (
        functions: (Rep[Domain] => Rep[RangeA], Rep[Domain] => Rep[RangeB])
    ): Rep[Domain] => Rep[(RangeA, RangeB)] =
        (x: Rep[Domain]) => (functions._1 (x), functions._2 (x))

}
