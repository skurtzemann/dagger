// Yarn is a package manager for Javascript applications
package yarn

import (
	"strings"

	"dagger.io/dagger"
	"dagger.io/dagger/engine"

	"universe.dagger.io/alpine"
	"universe.dagger.io/bash"
)

// Build a Yarn package
#Build: {
	// Application source code
	source: dagger.#FS

	// working directory to use
	cwd: *"." | string

	// Write the contents of `environment` to this file,
	// in the "envfile" format
	writeEnvFile: string | *""

	// Read build output from this directory
	// (path must be relative to working directory)
	buildDir: string | *"build"

	// Run this yarn script
	script: string | *"build"

	// Fix for shadowing issues
	let yarnScript = script

	// Cache to use, passed by the caller
	cache: engine.#CacheDir

	// Optional arguments for the script
	args: [...string] | *[]

	// Secret variables
	// FIXME: not implemented. Are they needed?
	secrets: [string]: dagger.#Secret

	// FIXME: Yarn's version depends on Alpine's version
	// Yarn version
	// yarnVersion: *"=~1.22" | string

	// FIXME: custom base image not supported
	_buildImage: alpine.#Build & {
		packages: {
			bash: {}
			yarn: {}
		}
	}

	// Run yarn in a docker container
	container: bash.#Run & {
		image: _buildImage.output

		// FIXME: move shell script to its own file
		script: contents: #"""
			# Create $ENVFILE_NAME file if set
			[ -n "$ENVFILE_NAME" ] && echo "$ENVFILE" > "$ENVFILE_NAME"

			yarn --cwd "$YARN_CWD" install --production false

			opts=( $(echo $YARN_ARGS) )
			yarn --cwd "$YARN_CWD" run "$YARN_BUILD_SCRIPT" ${opts[@]}
			mv "$YARN_BUILD_DIRECTORY" /build
			"""#

		mounts: {
			"yarn cache": {
				dest:     "/cache/yarn"
				contents: cache
			}
			"package source": {
				dest:     "/src"
				contents: source
			}
		}

		export: directories: "/build": _

		env: {
			YARN_BUILD_SCRIPT:    yarnScript
			YARN_ARGS:            strings.Join(args, "\n")
			YARN_CACHE_FOLDER:    "/cache/yarn"
			YARN_CWD:             cwd
			YARN_BUILD_DIRECTORY: buildDir
			if writeEnvFile != "" {
				ENVFILE_NAME: writeEnvFile
				ENVFILE:      strings.Join([ for k, v in env {"\(k)=\(v)"}], "\n")
			}
		}

		workdir: "/src"
	}

	// The final contents of the package after build
	output: container.export.directories."/build".contents
}
