package sandbox.ast

import scala.virtualization.lms.common._
import sandbox.ast.sql.syntax.SelectClause

/**
 *
 * @author: Ralf Mitschke
 */
package object sql
  extends LiftAll with ScalaOpsPkg with ScalaOpsPkgExp
{
  val ir = this

  def printAST[Domain: Manifest, Range: Manifest](clause: SelectClause[Domain, Range]) {
    Predef.println(reifyEffects(clause.function))
  }


}