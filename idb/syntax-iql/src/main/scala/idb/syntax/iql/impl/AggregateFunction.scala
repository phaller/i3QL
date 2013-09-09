package idb.syntax.iql.impl


import idb.syntax.iql.IR._
import idb.syntax.iql._

/**
 * @author Mirko Köhler
 */
case class AggregateFunction[Domain : Manifest, AggregateRange : Manifest](
	start : AggregateRange,
	added : Rep[((Domain, AggregateRange)) => AggregateRange],
	removed : Rep[((Domain, AggregateRange)) => AggregateRange],
	updated : Rep[((Domain, Domain, AggregateRange)) => AggregateRange]
) extends AGGREGATE_FUNCTION[Domain, AggregateRange]
{

}
