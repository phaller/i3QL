package sae.profiler

import sae.collections._
import sae.bytecode.model._
import sae.syntax.RelationalAlgebraSyntax._
import sae.util._

class JEditDatabase extends sae.bytecode.BytecodeDatabase {

    def readBytecode : Unit =
        {
            addArchiveAsResource("jedit-4.3.3-win.jar")
        }

}

object JEditProfiler {

    implicit val iterations = 5 
    def main(args : Array[String]) : Unit = {
        write( "no query", profile( noQueries) )
        write( "classfile(X)", profile(allClassfilesQuery) )
        write( "classfile_method(X)", profile(allClassfileMethodsQuery) )
        write( "classfile(X); classfile_method(X)", profile(allClassfilesAndMethodsQuery) )
        // TODO read classfiles into memory and just feed from in-memory lists
    }

    def noQueries : Unit = {
        val db = new JEditDatabase()
        db.readBytecode
    }

    def allClassfilesQuery : Unit = {
        val db = new JEditDatabase()
        val query : QueryResult[ClassFile] = db.classfiles
        db.readBytecode
    }
    def allClassfileMethodsQuery : Unit = {
        val db = new JEditDatabase()
        val query : QueryResult[Method] = db.classfile_methods
        db.readBytecode
    }
    
    def allClassfilesAndMethodsQuery : Unit = {
        val db = new JEditDatabase()
        val q1 : QueryResult[ClassFile] = db.classfiles
        val q2 : QueryResult[Method] = db.classfile_methods
        db.readBytecode
    }
    
    // count classes beginning with de.tud .... (think of effective filter) 
    
    // count methods of these classes w/o join 
    
    
    
    def profile(f: => Unit)( implicit times : Int = 1) : Array[Timer] = {
        var i = 0;
        val timers = new Array[Timer](times)
        while( i < times )
        {
            val timer = new Timer()
            f
            timer.stop;
            timers(i) = timer
            i += 1
        }
        return timers
    }
    
    def write(name: String, profile : Array[Timer]) : Unit = {
        print(name + " : ")
        val t = Timer.median(profile)
        println( t.elapsedSecondsWithUnit )
    }
}