# nomadsl

Nomadsl is a Ruby DSL for generating Nomad job specification files.

Methods mapping to keys and attributes described in the Nomad Job Specification
(https://www.nomadproject.io/docs/job-specification/index.html) are defined in
an includable module.

The mapping of key and attribute names to method names is generally one-to-one.

## Example: DSL direct to stdout

Simply `require 'nomadsl/dsl` and the DSL methods will be injected into the
root namespace. For example, this source file:

    #!/usr/bin/env ruby

    require 'nomadsl/dsl'

    job "example" do
      type "batch"
      region "iad"
      datacenters "prod"
      parameterized(payload: "required")
      group "work" do
        task "work" do
          vault(policies: ["example-job"])
          meta(aws_region: "ap-southeast-2")
          dispatch_payload(file: "message.txt")
          preloaded_vault_aws_creds("iam", "iam/sts/example-iam")
          artifact(source: "s3.amazonaws.com/example-bucket/example-job/script.sh")
          config(command: "script.sh")
        end
      end
    end

Will generate this output:

    $ ruby example.nomadsl
    job "example" {
      type = "batch"
      region = "iad"
      datacenters = ["prod"]

      parameterized {
        payload = "required"
      }

      group "work" {
        task "work" {
          driver = "exec"

          vault {
            policies = ["example-job"]
          }

          meta {
            aws_region = "ap-southeast-2"
          }

          dispatch_payload {
            file = "message.txt"
          }

          template {
            destination = "secrets/iam.env"
            data = <<BLOB
    {{with secret "iam/sts/example-iam"}}
    AWS_ACCESS_KEY_ID={{.Data.access_key}}
    AWS_SECRET_ACCESS_KEY={{.Data.secret_key}}
    AWS_SESSION_TOKEN={{.Data.security_token}}
    {{end}}
    BLOB
            env = true
          }

          artifact {
            source = "s3.amazonaws.com/example-bucket/example-job/script.sh"
          }

          config {
            command = "script.sh"
          }
        }
      }
    }

## Using `nomadsl` as the interpreter

As of 0.1.4, you can also set your shbang line to use `nomadsl` as the
interpreter of the script. This will evaluate everything as Ruby, but with the
necessary `nomadsl` boilerplate already built in:

    #!/usr/bin/env nomadsl

    job "nomadsl-example" do
      # ...
    end

If the file is then marked as executable, you can simply run it to generate
the corresponding Nomad job specification.

## Other uses

By requiring only `nomadsl`, you can inject these methods into another class:

    #!/usr/bin/env ruby

    require 'nomadsl'

    class Example
      include Nomadsl

      def generate
        @result = job "example" do
          # ...
        end
      end
    end

    puts Example.new.generate

## Roadmap

* Make all attributes explicitly callable
* Make subkeys embeddable in arglists if sensible
* Allow injecting comments into the rendered file
* Finish custom config blocks for each task driver
* Make errors report their correct location

## Contributing

I'm happy to accept suggestions, bug reports, and pull requests through Github.

## License

This software is public domain. No rights are reserved. See LICENSE for more
information.
