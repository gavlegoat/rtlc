val scala3Version = "3.4.1"

lazy val root = project
  .in(file("."))
  .settings(
    name := "trace",
    version := "0.1.0-SNAPSHOT",

    scalaVersion := scala3Version,

    libraryDependencies += "org.scalameta" %% "munit" % "0.7.29" % Test,
    libraryDependencies += "org.scala-lang" %% "toolkit" % "0.1.7"
  )
