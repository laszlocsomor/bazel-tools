load("@bazel_skylib//lib:shell.bzl", "shell")

_CONTENT_PREFIX = """#!/usr/bin/env bash

set -euo pipefail

"""

def _multirun_impl(ctx):
    runfiles = ctx.runfiles()
    content = [_CONTENT_PREFIX]

    for command in ctx.attr.commands:
        defaultInfo = command[DefaultInfo]
        if defaultInfo.files_to_run == None:
            fail("%s is not executable" % command.label, attr = "commands")
        exe = defaultInfo.files_to_run.executable
        if exe == None:
            fail("%s does not have an executable file" % command.label, attr = "commands")

        default_runfiles = defaultInfo.default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)
        content.append("echo Running %s\n./%s $@\n" % (shell.quote(str(command.label)), shell.quote(exe.short_path)))

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "".join(content),
        is_executable = True,
    )
    return [DefaultInfo(
        files = depset([out_file]),
        runfiles = runfiles,
        executable = out_file,
    )]

_multirun = rule(
    implementation = _multirun_impl,
    attrs = {
        "commands": attr.label_list(
            allow_empty = True,  # this is explicitly allowed - generated invocations may need to run 0 targets
            mandatory = True,
            allow_files = True,
            doc = "Targets to run in specified order",
            cfg = "target",
        ),
    },
    executable = True,
)

def multirun(**kwargs):
    tags = kwargs.get("tags", [])
    if "manual" not in tags:
        tags.append("manual")
        kwargs["tags"] = tags
    _multirun(
        **kwargs
    )

def _command_impl(ctx):
    runfiles = ctx.runfiles()
    defaultInfo = ctx.attr.command[DefaultInfo]

    default_runfiles = defaultInfo.default_runfiles
    if default_runfiles != None:
        runfiles = runfiles.merge(default_runfiles)

    str_env = [
        "%s=%s" % (k, shell.quote(v))
        for k, v in ctx.attr.environment.items()
    ]
    str_unqouted_env = [
        "%s=%s" % (k, v)
        for k, v in ctx.attr.raw_environment.items()
    ]
    str_args = [
        "%s=%s" % (k, shell.quote(v))
        for k, v in ctx.attr.arguments.items()
    ]
    command_elements = ["exec env"] + \
                       str_env + \
                       str_unqouted_env + \
                       ["./%s" % shell.quote(defaultInfo.files_to_run.executable.short_path)] + \
                       str_args + \
                       ["$@\n"]

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = _CONTENT_PREFIX + " ".join(command_elements),
        is_executable = True,
    )
    return [
        DefaultInfo(
            files = depset([out_file]),
            runfiles = runfiles,
            executable = out_file,
        ),
    ]

_command = rule(
    implementation = _command_impl,
    attrs = {
        "arguments": attr.string_dict(
            doc = "Dictionary of command line arguments",
        ),
        "environment": attr.string_dict(
            doc = "Dictionary of environment variables",
        ),
        "raw_environment": attr.string_dict(
            doc = "Dictionary of unqouted environment variables",
        ),
        "command": attr.label(
            mandatory = True,
            allow_files = True,
            executable = True,
            doc = "Target to run",
            cfg = "target",
        ),
    },
    executable = True,
)

def command(**kwargs):
    tags = kwargs.get("tags", [])
    if "manual" not in tags:
        tags.append("manual")
        kwargs["tags"] = tags
    _command(
        **kwargs
    )
