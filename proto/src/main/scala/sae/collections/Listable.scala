package sae
package collections

/**
 * Trait used for testing purposes
 */
trait Listable[V <: AnyRef] {

    def foreach[T](f : (V) => T)

    /**
     * Converts the data of the view into a list representation.
     * This can be a costly operation and should mainly be used for testing.
     */
    def asList : List[V] =
        {
            var l : List[V] = List()
            foreach(v =>
                {
                    l = l :+ v
                }
            )
            l
        }

}