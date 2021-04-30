SonatypePublishInfo = provider(
    fields = {
        "coordinates": "Maven coordinates for the project, which may be None",
        "pom": "Pom.xml file for metadata",
        "javadocs": "Javadoc jar file for documentation files",
        "artifact_jar": "Jar with the code and metadata for execution",
        "source_jar": "Jar with the source code for review",
    },
)

_TEMPLATE = """#!/usr/bin/env bash

echo "Uploading {coordinates} to {maven_repo}"
./uploader --sonatype-repository={maven_repo} {pgp_passphrase} {user} {password} {profile} {coordinates} {artifact} {source} {doc} 
"""

def _sonatype_publish_impl(ctx):
    executable = ctx.actions.declare_file("%s-publisher" % ctx.attr.name)

    maven_repo = ctx.var.get("maven_repo", "''")
    user = ctx.var.get("maven_user", "''")
    password = ctx.var.get("maven_password", "''")
    profile = ctx.var.get("maven_profile", "''")
    pgp_passphrase = ctx.var.get("pgp_passphrase", "''")
    coordinates_split = ctx.attr.coordinates.split(":")
    artifact = coordinates_split[1]
    version = coordinates_split[2]
    filename = "{}-{}".format(artifact, version)
    artifact_jar = "%s.jar" % filename
    docs_jar = "%s-javadoc.jar" % filename
    sources_jar = "%s-sources.jar" % filename


    ctx.actions.write(
        output = executable,
        is_executable = True,
        content = _TEMPLATE.format(
            coordinates = ctx.attr.coordinates,
            pgp_passphrase = pgp_passphrase,
            maven_repo = maven_repo,
            password = password,
            user = user,
            profile = profile,
            artifact = artifact_jar,
            source = sources_jar,
            doc = docs_jar,
        ),
    )

    return [
        DefaultInfo(
            files = depset([executable]),
            executable = executable,
            runfiles = ctx.runfiles(
                symlinks = {
                    artifact_jar: ctx.file.artifact_jar,
                    docs_jar: ctx.file.javadocs,
                    sources_jar: ctx.file.source_jar,
                    "uploader": ctx.executable._uploader,
                },
                collect_data = True,
            ).merge(ctx.attr._uploader[DefaultInfo].data_runfiles),
        ),
        SonatypePublishInfo(
            coordinates = ctx.attr.coordinates,
            artifact_jar = ctx.file.artifact_jar,
            javadocs = ctx.file.javadocs,
            source_jar = ctx.file.source_jar,
            pom = ctx.file.pom,
        ),
    ]

sonatype_publish = rule(
    _sonatype_publish_impl,
    doc = """Publish artifacts to a maven repository.

The maven repository may accessed locally remotely using an `https://` URL.
The following flags may be set using `--define`:
  gpg_sign: Whether to sign artifacts using GPG
  maven_repo: A URL for the repo to use. May be "https" or "file".
  maven_user: The user name to use when uploading to the maven repository.
  maven_password: The password to use when uploading to the maven repository.

When signing with GPG, the current default key is used.
""",
    executable = True,
    attrs = {
        "coordinates": attr.string(
            mandatory = True,
        ),
        "pom": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "javadocs": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "artifact_jar": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "source_jar": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_uploader": attr.label(
            executable = True,
            cfg = "host",
            default = "//src/main/scala/org/jetbrains/bazel:SonatypeOpenAndPublish",
            allow_files = True,
        ),
    },
)
