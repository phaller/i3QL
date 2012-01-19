package unisson.model.mock.vespucci

import collection.JavaConversions
import de.tud.cs.st.vespucci.model.{IConstraint, IEnsemble}
import java.util.HashSet

/**
 *
 * Author: Ralf Mitschke
 * Date: 02.01.12
 * Time: 16:26
 *
 */
private case class EnsembleImpl(name: String, innerEnsembles : Set[IEnsemble])
    extends IEnsemble
{
    var query : String = ""

    def getDescription = ""

    def getName = name

    def getQuery = query

    def getSourceConnections = new HashSet[IConstraint]()

    def getTargetConnections = new HashSet[IConstraint]()

    def getInnerEnsembles = JavaConversions.setAsJavaSet(innerEnsembles)

    override def toString = "Ensemble(" + name +")"
}

object Ensemble
{
    def apply(name: String, query : String, innerEnsembles : Set[IEnsemble]) :IEnsemble =
    {
        val e = EnsembleImpl(name, innerEnsembles)
        e.query = query
        e
    }
}