package sae.test

import org.junit.{Assert, Test}
import sae.syntax.sql._
import sae.LazyView

/**
 *
 * Author: Ralf Mitschke
 * Date: 03.08.12
 * Time: 18:23
 *
 */
class SQLSyntaxTest
{

    @Test
    def testProjectSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        def Name(s: Student) = s.Name


        val names1: LazyView[String] = SELECT {
            (_: Student).Name
        } FROM students

        val names2: LazyView[String] = SELECT {
            Name(_: Student)
        } FROM students

        val names3: LazyView[String] = FROM(students) SELECT {
            Name(_)
        }

        def SName: Student => String = s => s.Name

        // the scala compiler can not infer the type of the anonymous function, because the function needs a type before it is passed as parameter
        val names4: LazyView[String] = FROM(students) SELECT ((_: Student).Name)

        // but we can do this
        val names5: LazyView[String] = FROM(students) SELECT (SName)

        Assert.assertEquals(2, names1.size)
        Assert.assertEquals(2, names2.size)
        Assert.assertEquals(2, names3.size)
        Assert.assertEquals(2, names4.size)
        Assert.assertEquals(2, names5.size)

    }

    @Test
    def testProjectFunctionTuplesFieldsSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        def Name: Student => String = s => s.Name

        def Id: Student => Integer = s => s.Id

        // but we can do this
        val select: LazyView[(String, Integer)] = FROM(students) SELECT {
            (Name, Id)
        }

        Assert.assertEquals(2, select.size)

    }

    @Test
    def testProjectStarSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val allStudents: LazyView[Student] = SELECT(*) FROM (students)

        Assert.assertEquals(2, allStudents.size)

    }


    @Test
    def testProjectDistinctStarSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        // add sally twice
        students += sally

        val allStudents: LazyView[Student] = SELECT DISTINCT (*) FROM (students)

        Assert.assertEquals(2, allStudents.size)

    }


    @Test
    def testDistinctProjectSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        // add sally twice
        students += sally

        def Name: Student => String = s => s.Name

        val names: LazyView[String] = FROM(students) SELECT DISTINCT (Name)

        Assert.assertEquals(2, names.size)
    }

    @Test
    def testFilterSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val selection: LazyView[Student] = SELECT (*) FROM (students) WHERE (_.Name == "sally")

        Assert.assertEquals(1, selection.size)

        Assert.assertEquals(Some(sally), selection.singletonValue)

    }

    @Test
    def testDistinctFilterSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy
        students += sally

        val selection: LazyView[Student] = SELECT DISTINCT (*) FROM (students) WHERE (_.Name == "sally")

        Assert.assertEquals(1, selection.size)

        Assert.assertEquals(Some(sally), selection.singletonValue)

    }

    @Test
    def testMultipleFilterConjunctionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val selection: LazyView[Student] = SELECT (*) FROM (students) WHERE (_.Name == "sally") AND (_.Id == 12346)

        val selectionNative: LazyView[Student] = SELECT(*) FROM (students) WHERE ((s: Student) => s.Name == "sally" && s
                .Id == 12346)

        Assert.assertEquals(1, selection.size)

        Assert.assertEquals(Some(sally), selection.singletonValue)

        Assert.assertEquals(selection.asList, selectionNative.asList)

    }


    @Test
    def testMultipleFilterDisjunctionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val selection: LazyView[Student] = SELECT(*) FROM (students) WHERE (_.Name == "sally") OR (_.Id == 12345)

        Assert.assertEquals(2, selection.size)

        Assert.assertEquals(
            List(john, sally),
            selection.asList.sortBy(_.Id)
        )

    }

    @Test
    def testMultipleFilterInlineSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val sally2 = Student(636363, "sally")
        students += sally2

        val selection: LazyView[Student] = SELECT(*) FROM (students) WHERE (_.Name == "sally") AND (((_:Student).Id == 12346) OR (_.Id == 636363))

        Assert.assertEquals(2, selection.size)

        Assert.assertEquals(
            List(sally, sally2),
            selection.asList.sortBy(_.Id)
        )

    }


    @Test
    def testMultipleFilterDisjunctionWithProjectionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        def Name: Student => String = x => x.Name

        val selection: LazyView[String] = SELECT(Name) FROM (students) WHERE (_.Name == "sally") OR (_.Id == 12345)

        Assert.assertEquals(2, selection.size)

        Assert.assertEquals(
            List("john", "sally"),
            selection.asList.sorted
        )

    }


    @Test
    def testCrossProductStartAtFromWithProjectionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val courses = database.courses.copy // make a local copy

        def Name: Student => String = x => x.Name

        def CourseName: Course => String = x => x.Name

        val selection1: LazyView[(String, String)] = FROM(students, courses) SELECT ((s: Student, c: Course) => (s
                .Name, c.Name))

        // this causes ambiguites with the select distinct syntax
        //val selection2: LazyView[(String, String)] = FROM (students, courses) SELECT ((Name, CourseName))

        val selection3: LazyView[(String, String)] = FROM(students, courses) SELECT(Name, CourseName)

        Assert.assertEquals(
            List(
                ("john", "EiSE"),
                ("john", "SE-D&C"),
                ("sally", "EiSE"),
                ("sally", "SE-D&C")
            ),
            selection1.asList.sorted
        )

        //Assert.assertEquals (selection1.asList.sorted, selection2.asList.sorted)

        Assert.assertEquals(selection1.asList.sorted, selection3.asList.sorted)
    }

    @Test
    def testDistinctCrossProductStartAtFromWithProjectionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        students += sally

        val courses = database.courses.copy // make a local copy

        def Name: Student => String = x => x.Name

        def CourseName: Course => String = x => x.Name

        val selection1: LazyView[(String, String)] = FROM(students, courses) SELECT DISTINCT((s: Student,
                                                                                              c: Course) => (s.Name, c
                .Name))

        // this causes ambiguites with the select syntax
        //val selection2: LazyView[(String, String)] = FROM (students, courses) SELECT DISTINCT ((Name, CourseName))

        val selection3: LazyView[(String, String)] = FROM(students, courses) SELECT DISTINCT(Name, CourseName)

        Assert.assertEquals(
            List(
                ("john", "EiSE"),
                ("john", "SE-D&C"),
                ("sally", "EiSE"),
                ("sally", "SE-D&C")
            ),
            selection1.asList.sorted
        )

        //Assert.assertEquals (selection1.asList.sorted, selection2.asList.sorted)

        Assert.assertEquals(selection1.asList.sorted, selection3.asList.sorted)

    }

    @Test
    def testCrossProductStartAtFromNoProjectionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val courses = database.courses.copy // make a local copy

        val selection1: LazyView[(Student, Course)] = FROM(students, courses) SELECT (*)

        Assert.assertEquals(
            List(
                (john, eise),
                (john, sed),
                (sally, eise),
                (sally, sed)
            ),
            selection1.asList.sortBy(x => (x._1.Name, x._2.Name))
        )

    }

    @Test
    def testDistinctCrossProductStartAtFromNoProjectionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        students += sally

        val courses = database.courses.copy // make a local copy

        val selection1: LazyView[(Student, Course)] = FROM(students, courses) SELECT DISTINCT(*)

        Assert.assertEquals(
            List(
                (john, eise),
                (john, sed),
                (sally, eise),
                (sally, sed)
            ),
            selection1.asList.sortBy(x => (x._1.Name, x._2.Name))
        )

    }


    @Test
    def testCrossProductStartAtFromNoProjectionWithSelectionSyntax() {

        val database = new StudentCoursesDatabase()

        import database._

        val students = database.students.copy // make a local copy

        val courses = database.courses.copy // make a local copy

        def Name: Student => String = x => x.Name

        val selection1: LazyView[(Student, Course)] = FROM(students, courses) SELECT (*) WHERE (x => x._1
                .Name == "john") OR (x => x._1.Name == "sally")
        /*
                val selection2: LazyView[(Student, Course)] = FROM (students, courses) SELECT (*) WHERE ( {
                    (s: Student) => s.Name == "john" || s.Name == "sally"
                }, *)
        */
        Assert.assertEquals(
            List(
                (john, eise),
                (john, sed),
                (sally, eise),
                (sally, sed)
            ),
            selection1.asList.sortBy(x => (x._1.Name, x._2.Name))
        )

        //Assert.assertEquals (selection1.asList.sortBy (x => (x._1.Name, x._2.Name)), selection2.asList.sortBy (x => (x._1.Name, x._2.Name)))
    }
}