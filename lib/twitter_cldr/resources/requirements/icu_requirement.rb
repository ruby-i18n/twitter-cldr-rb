# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'open-uri'

module TwitterCldr
  module Resources
    module Requirements

      # This requirement makes use of the JarClassLoader package (https://github.com/kamranzafar/JCL)
      # to load ICU in an isolated environment to keep different versions of the
      # library separate. If ICU versions are not kept separate, the one that's
      # first on the classpath wins, which can be surprising if you're not
      # expecting it. Oh, and it can break all the tests.
      class IcuRequirement
        POM_FILE = File.join(TwitterCldr::VENDOR_DIR, 'maven', 'pom.xml').freeze

        attr_reader :version

        def initialize(version)
          @version = version
        end

        def prepare
          require 'java'

          pom.add_dependency('com.ibm.icu', 'icu4j', version)
          pom.add_dependency('org.xeustechnologies', 'jcl-core', '2.7')

          pom.install
          pom.require_jar('org.xeustechnologies', 'jcl-core')

          java_import 'org.xeustechnologies.jcl.JarClassLoader'
          class_loader.add(pom.get('com.ibm.icu', 'icu4j').path)
        end

        def get_class(name)
          get_java_class(name).ruby_class
        end

        def get_java_class(name)
          class_loader.load_class(name)
        end

        def load_class_from_file(path, class_name)
          java_import "java.io.ByteArrayInputStream"
          java_import "java.io.ByteArrayOutputStream"
          java_import "java.util.jar.JarEntry"
          java_import "java.util.jar.JarOutputStream"

          bytes = File.binread(path)
          buffer = ByteArrayOutputStream.new
          jar = JarOutputStream.new(buffer)

          jar.putNextEntry(JarEntry.new("#{class_name}.class"))
          jar.write(bytes.to_java_bytes)
          jar.closeEntry
          jar.close

          class_loader.add(ByteArrayInputStream.new(buffer.toByteArray))
          class_loader.load_class(class_name).ruby_class
        end

        private

        def class_loader
          @class_loader ||= JarClassLoader.new
        end

        def pom
          @pom ||= PomManager.new(POM_FILE)
        end
      end

    end
  end
end
