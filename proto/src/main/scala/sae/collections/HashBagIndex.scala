package sae
package collections

import java.util.ArrayList


/**
 * An index backed by a guave ListMultimap.
 * The index may have multiple values for a single key.
 * The index stores multiple equal key-value pairs.
 * Thus this Index is suited for bag semantics.
 *
 * Multi-value semantics is a pre-requisite for the index to work with
 * arbitrary data. Parts of a tuple may be defined as index and must not be
 * unique in any way.
 */
class HashBagIndex[K <: AnyRef, V <: AnyRef](
    val relation: MaterializedView[V],
    val keyFunction: V => K
)
        extends Collection[(K, V)]
                with Index[K, V]
{

    private val map = com.google.common.collect.LinkedListMultimap.create[K, V]()

    protected def put_internal(key: K, value: V)
    {
        map.put(key, value)
    }

    protected def get_internal(key: K): Option[Traversable[V]] =
    {
        val l = map.get(key)
        if (l.isEmpty)
            None
        Some(new ValueListTraverser(l))
    }

    private class ValueListTraverser[V](val values: java.util.List[V]) extends Traversable[V]
    {
        def foreach[T](f: V => T)
        {
            val it: java.util.Iterator[V] = values.iterator
            while (it.hasNext) {
                val next = it.next()
                f(next)
            }
        }
    }

    protected def isDefinedAt_internal(key: K): Boolean = map.containsKey(key)


    protected def elementCountAt_internal(key: K) =
        if( !map.containsKey(key) )
        {
            0
        }
        else
        {
            map.get(key).size()
        }

    def materialized_foreach[U](f: ((K, V)) => U)
    {
        val it: java.util.Iterator[java.util.Map.Entry[K, V]] = map.entries().iterator
        while (it.hasNext) {
            val next = it.next()
            f((next.getKey, next.getValue))
        }
    }

    def materialized_size: Int =
        map.size

    def materialized_singletonValue: Option[(K, V)] =
    {
        if (size != 1)
            None
        else {
            val next = map.entries().iterator().next()
            Some((next.getKey, next.getValue))
        }
    }

    protected def materialized_contains(v: (K, V)) =
        map.containsEntry(v._1, v._2)

    def add_element(kv: (K, V))
    {
        map.put(kv._1, kv._2)
    }

    def remove_element(kv: (K, V))
    {
        map.remove(kv._1, kv._2)
    }

    def update_element(oldKey : K, oldV : V, newKey : K, newV : V)
    {
        val list = map.get(oldKey)
        val it = list.iterator()
        val retainedMap = new java.util.LinkedList[V]()
        val newMap = new java.util.LinkedList[V]()
        while( it.hasNext )
        {
            val next = it.next()
            if( next == oldV )
                newMap.add(newV)
            else
                retainedMap.add(next)
        }
        map.replaceValues(oldKey, retainedMap)
        map.putAll(newKey, newMap)
    }

}
