package idb.demo

import java.io._
import java.nio.file.{Paths, Files}

import idb.{Relation, BagTable}


/**
 * @author Mirko Köhler
 */
object Main {


	def main(args : Array[String]): Unit = {
		new WordCountBenchmark(WordCountPerWordFactory).run()
	}
}
