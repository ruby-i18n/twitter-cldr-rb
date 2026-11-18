# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'yaml'
require 'zlib'
require 'parallel'

module TwitterCldr
  module Resources

    class JavaWrapper
      def self.new(...)
        instance = allocate
        instance.send(:initialize, ...)
        instance.build_module
      end

      def initialize(req, classpath, &block)
        @req = req
        @classpath = classpath
        @static_methods = []
        @instance_methods = []
        @consts = []
        @fields = []

        instance_exec(&block)
      end

      def expose_instance(name, *arg_types)
        @instance_methods << [name, arg_types]
      end

      def expose_static(name, *arg_types)
        @static_methods << [name, arg_types]
      end

      def expose_const(name)
        @consts << name
      end

      def expose_field(name)
        @fields << name
      end

      def build_module
        static_methods = @static_methods
        instance_methods = @instance_methods
        consts = @consts
        fields = @fields

        java_class = @req.get_java_class(@classpath)

        instance_mod = Module.new do
          instance_methods.each do |method_name, arg_types|
            mtd = java_class.getDeclaredMethod(method_name, *arg_types)
            mtd.setAccessible(true)

            define_method(method_name) do |*args|
              mtd.invoke(@java_instance, *args)
            end
          end
        end

        class_mod = Module.new do
          static_methods.each do |method_name, arg_types|
            mtd = java_class.getDeclaredMethod(method_name, *arg_types)
            mtd.setAccessible(true)

            define_method(method_name) do |*args|
              mtd.invoke(nil, *args)
            end
          end
        end

        result = Module.new
        result.module_exec(instance_mod, class_mod) do |instance_mod, class_mod|
          attr_reader :java_instance

          def initialize(java_instance)
            @java_instance = java_instance
          end

          define_singleton_method(:included) do |base|
            base.include(instance_mod)
            base.extend(class_mod)
          end

          consts.each do |const_name|
            field = java_class.getDeclaredField(const_name)
            field.setAccessible(true)

            const_set(const_name, field.static_value)
          end

          fields.each do |field_name|
            field = java_class.getDeclaredField(field_name)
            field.setAccessible(true)

            define_method(field_name) do
              field.get(@java_instance.java_object)
            end
          end
        end

        result
      end
    end

    class CollationDataImporter < Importer

      requirement :icu, Versions.icu_version
      locales TwitterCldr.supported_locales
      ruby_engine :jruby
      output_path File.join('collation', 'data')

      HANGUL_BASE = 0xAC00
      JAMO_L_COUNT = 19
      JAMO_V_COUNT = 21
      JAMO_T_COUNT = 28

      CONTEXT_CE = -1
      FALLBACK_CE = -2

      def after_prepare
        icu = requirements[:icu]

        collation = Class.new do
          include(JavaWrapper.new(icu, "com.ibm.icu.impl.coll.Collation") do
            expose_static :isSpecialCE32, Java::int
            expose_static :tagFromCE32, Java::int
            expose_static :ceFromSimpleCE32, Java::int
            expose_static :ceFromLongPrimaryCE32, Java::int
            expose_static :ceFromLongSecondaryCE32, Java::int
            expose_static :latinCE0FromCE32, Java::int
            expose_static :latinCE1FromCE32, Java::int
            expose_static :unassignedCEFromCodePoint, Java::int

            expose_static :indexFromCE32, Java::int
            expose_static :lengthFromCE32, Java::int

            expose_const :LONG_PRIMARY_TAG
            expose_const :LONG_SECONDARY_TAG
            expose_const :LATIN_EXPANSION_TAG
            expose_const :EXPANSION_TAG
            expose_const :EXPANSION32_TAG
            expose_const :OFFSET_TAG
            expose_const :HANGUL_TAG
            expose_const :IMPLICIT_TAG
            expose_const :CONTRACTION_TAG
            expose_const :PREFIX_TAG
            expose_const :U0000_TAG
            expose_const :DIGIT_TAG
            expose_const :FALLBACK_TAG

            expose_const :CONTRACT_SINGLE_CP_NO_MATCH
            expose_const :CONTRACT_NEXT_CCC
            expose_const :CONTRACT_TRAILING_CCC
          end)
        end

        self.class.const_set(:Collation, collation)

        collation_data = Class.new do
          include(JavaWrapper.new(icu, "com.ibm.icu.impl.coll.CollationData") do
            expose_field :ces
            expose_field :ce32s
            expose_field :jamoCE32s
            expose_field :contexts

            expose_instance :getCEFromOffsetCE32, Java::int, Java::int
            expose_instance :getCE32FromContexts, Java::int
          end)

          extend Forwardable

          def_delegators :@java_instance, :getCE32, :compressibleBytes
        end

        self.class.const_set(:CollationData, collation_data)

        collator = Class.new do
          include(JavaWrapper.new(icu, "com.ibm.icu.text.RuleBasedCollator") do
            expose_field :settings

            expose_instance :isFrenchCollation
            expose_instance :isUpperCaseFirst
            expose_instance :isLowerCaseFirst
            expose_instance :isAlternateHandlingShifted
            expose_instance :isCaseLevel
            expose_instance :getVariableTop
            expose_instance :getMaxVariable
          end)
        end

        self.class.const_set(:Collator, collator)

        collation_settings = Class.new do
          include(JavaWrapper.new(icu, "com.ibm.icu.impl.coll.CollationSettings") do
            expose_field :options
            expose_field :reorderTable
            expose_field :minHighNoReorder
            expose_field :reorderRanges
          end)

          extend Forwardable

          def_delegators :@java_instance, :getAlternateHandling
        end

        self.class.const_set(:CollationSettings, collation_settings)
      end

      def execute
        dump_root
        dump_locales
      end

      private

      def dump_root
        dump_by_block("root", data_for_root)
        puts "Dumped root data"

        blocks = TwitterCldr::Shared::CodePoint.properties.property_values_for("Block")
        all_ranges = blocks.map do |block|
          TwitterCldr::Shared::CodePoint
            .properties
            .code_points_for_property("Block", block)
            .ranges
            .first
        end

        missing = TwitterCldr::Utils::RangeSet.new([1..0x10FFFF]).subtract(
          TwitterCldr::Utils::RangeSet.new(all_ranges)
        )

        count = 0

        finish = -> (*) do
          count += 1
          STDOUT.write("\rDumped #{count} of #{missing.ranges.size} missing ranges for root")
        end

        Parallel.each(missing.ranges, in_threads: [Etc.nprocessors / 2, 1].max, finish: finish) do |range|
          dump_range(range, "root", data_for_root)
        end

        puts
      end

      def dump_locales
        count = 0

        finish = -> (locale, *) do
          count += 1
          STDOUT.write "\rImported tailoring for #{locale}, #{count} of #{params[:locales].size} total"
        end

        Parallel.each(params[:locales], in_threads: [Etc.nprocessors / 2, 1].max, finish: finish) do |locale_sym|
          dump_locale(locale_sym)
        end

        puts
      end

      def dump_locale(locale)
        dump_by_block(locale, data_for_locale(locale))
      end

      def dump_by_block(locale, data)
        each_block do |cp_range|
          dump_range(cp_range, locale, data)
        end

        output_file = File.join(params[:output_path], "#{locale}.dump")
        FileUtils.mkdir_p(File.dirname(output_file))

        File.write(
          output_file,
          Zlib::Deflate.deflate(
            Marshal.dump({
              settings: data[:settings],
              compressible_bytes: data[:compressible_bytes],
            }),

            Zlib::BEST_COMPRESSION
          )
        )
      end

      def dump_range(cp_range, locale, data)
        cps = cp_range.to_a

        new_trie = data[:trie]&.slice(*cps)
        contexts_for_block = data[:contexts].slice(*cps)
        return if (!new_trie || new_trie.empty?) && contexts_for_block.empty?

        output_file = File.join(params[:output_path], locale.to_s, "#{cp_range.first}-#{cp_range.last}.dump")
        FileUtils.mkdir_p(File.dirname(output_file))

        File.write(
          output_file,
          Zlib::Deflate.deflate(
            Marshal.dump({
              trie: new_trie,
              contexts: contexts_for_block,
            }),

            Zlib::BEST_COMPRESSION
          )
        )
      end

      def each_block
        return to_enum(__method__) unless block_given?

        blocks = TwitterCldr::Shared::CodePoint.properties.property_values_for("Block")

        blocks.each do |block|
          cp_range = TwitterCldr::Shared::CodePoint
            .properties
            .code_points_for_property("Block", block)
            .ranges
            .first

          yield cp_range
        end
      end

      def data_for_root
        {
          **mappings_for(root_collation_data),
          settings: settings_for(ulocale_class::ROOT),
          compressible_bytes: root_collation_data.compressibleBytes.to_a,
        }
      end

      def root_collation_data
        @root_collation_data ||= CollationData.new(
          requirements[:icu]
            .get_class("com.ibm.icu.impl.coll.CollationRoot")
            .getData
        )
      end

      def data_for_locale(locale)
        ulocale = ulocale_class.new(locale)
        valid_locale = output_class.new
        tailoring = collation_loader_class.loadTailoring(ulocale, valid_locale)
        collation_data = CollationData.new(tailoring.data)

        locale_data = if collation_data.java_instance == root_collation_data.java_instance
          empty_mappings
        else
          mappings_for(collation_data)
        end

        locale_data[:compressible_bytes] = collation_data.compressibleBytes.to_a
        locale_data[:settings] = settings_for(ulocale)
        locale_data
      end

      def empty_mappings
        {
          trie: nil,
          contexts: {},
        }
      end

      STRENGTH_SHIFT = 12

      def settings_for(ulocale)
        collator = collator_for(ulocale)
        settings = CollationSettings.new(collator.settings.readOnly)

        {
          backward_secondary: collator.isFrenchCollation,
          uppercase_first: collator.isUpperCaseFirst,
          lowercase_first: collator.isLowerCaseFirst,
          alternate_handling: settings.getAlternateHandling,
          # There's a static method for this on CollationSettings, but I can't figure out how to call it so we do it manually instead.
          sorts_tertiary_uppercase_first: (settings.options & (collation_settings_class::CASE_LEVEL | collation_settings_class::CASE_FIRST_AND_UPPER_MASK)) == collation_settings_class::CASE_FIRST_AND_UPPER_MASK,
          strength: settings.options >> STRENGTH_SHIFT,
          alternate_handling_shifted: collator.isAlternateHandlingShifted,
          case_level: collator.isCaseLevel,
          variable_top: collator.getVariableTop & 0xFFFF_FFFF,
          reorder_table: settings.reorderTable&.to_a,
          min_high_no_reorder: settings.minHighNoReorder,
          reorder_ranges: settings.reorderRanges&.to_a,
          max_variable: case collator.getMaxVariable
            when reorder_codes::SPACE
              :space
            when reorder_codes::PUNCTUATION
              :punctuation
            when reorder_codes::SYMBOL
              :symbol
            when reorder_codes::CURRENCY
              :currency
            else
              raise "Unreachable"
          end
        }
      end

      def max_variable_for(ulocale)
        case collator_for(ulocale).getMaxVariable
          when reorder_codes::SPACE
            :space
          when reorder_codes::PUNCTUATION
            :punctuation
          when reorder_codes::SYMBOL
            :symbol
          when reorder_codes::CURRENCY
            :currency
          else
            raise "Unreachable"
        end
      end

      def collator_for(ulocale)
        collators[ulocale] ||= Collator.new(collator_class.get_instance(ulocale))
      end

      def collators
        @collators ||= {}
      end

      def mappings_for(collation_data)
        trie = TwitterCldr::Utils::Trie.new
        contexts = {}

        0.upto(0x10FFFF) do |cp|
          ce32 = collation_data.getCE32(cp)
          ce = resolve_ce32(cp, ce32, collation_data)
          next if ce == 0xC0  # skip fallbacks

          case ce
            when CONTEXT_CE
              tag = Collation.tagFromCE32(ce32)
              index = Collation.indexFromCE32(ce32)
              default_ce32 = collation_data.getCE32FromContexts(index)

              trie.add([cp], CONTEXT_CE)

              trie_iter = collation_data_bridge_class.contextsIterator(collation_data.java_instance, index)

              while trie_iter.hasNext
                entry = trie_iter.next
                suffix = entry.chars
                result_ce = resolve_ce32(cp, entry.value, collation_data)
                trie.add([cp, *suffix.to_s.codepoints], result_ce)
              end

              contexts[cp] = {
                direction: tag == Collation::PREFIX_TAG ? :backward : :forward,
                default_ce: resolve_ce32(cp, default_ce32, collation_data),
                single_cp_no_match: (ce32 & Collation::CONTRACT_SINGLE_CP_NO_MATCH) != 0,
                next_ccc: (ce32 & Collation::CONTRACT_NEXT_CCC) != 0,
                trailing_ccc: (ce32 & Collation::CONTRACT_TRAILING_CCC) != 0,
              }

            when FALLBACK_CE
              # trie.add([cp], FALLBACK_CE)

            else
              trie.add([cp], ce)
          end
        end

        {
          trie: dump_trie(trie.root),
          contexts: contexts,
        }
      end

      def dump_trie(node)
        return if node.children.empty?

        node.children.inject({}) do |memo, (key, child)|
          next memo if child.value == [0] && child.children.empty?

          memo[key] = { value: child.value, children: dump_trie(child) }
          memo
        end
      end

      def resolve_ce32(cp, ce32, collation_data)
        if !Collation.isSpecialCE32(ce32)
          [Collation.ceFromSimpleCE32(ce32)]
        else
          case Collation.tagFromCE32(ce32)
            when Collation::LONG_PRIMARY_TAG
              [Collation.ceFromLongPrimaryCE32(ce32)]

            when Collation::LONG_SECONDARY_TAG
              [Collation.ceFromLongSecondaryCE32(ce32)]

            when Collation::LATIN_EXPANSION_TAG
              [
                Collation.latinCE0FromCE32(ce32),
                Collation.latinCE1FromCE32(ce32),
              ]

            when Collation::EXPANSION32_TAG
              index = Collation.indexFromCE32(ce32)
              length = Collation.lengthFromCE32(ce32)

              index.upto(index + length - 1).flat_map do |i|
                resolve_ce32(cp, collation_data.ce32s[i], collation_data)
              end

            when Collation::EXPANSION_TAG
              index = Collation.indexFromCE32(ce32)
              length = Collation.lengthFromCE32(ce32)

              collation_data.ces[index, length].to_a

            when Collation::OFFSET_TAG
              [collation_data.getCEFromOffsetCE32(cp, ce32)]

            when Collation::HANGUL_TAG
              # resolve via Jamo mappings
              jamo_ce32s = collation_data.jamoCE32s
              l_idx = cp - HANGUL_BASE
              t_idx = l_idx % JAMO_T_COUNT
              l_idx /= JAMO_T_COUNT
              v_idx = l_idx % JAMO_V_COUNT
              l_idx /= JAMO_V_COUNT

              [].tap do |ces|
                ces += resolve_ce32(cp, jamo_ce32s[l_idx], collation_data)
                ces += resolve_ce32(cp, jamo_ce32s[JAMO_L_COUNT + v_idx], collation_data)

                if t_idx != 0
                  ces += resolve_ce32(cp, jamo_ce32s[JAMO_L_COUNT + JAMO_V_COUNT + t_idx - 1], collation_data)
                end
              end

            when Collation::IMPLICIT_TAG
              [Collation.unassignedCEFromCodePoint(cp)]

            when Collation::U0000_TAG
              resolve_ce32(cp, collation_data.ce32s[0], collation_data)

            when Collation::DIGIT_TAG
              # stores non-numeric ce32s
              index = Collation.indexFromCE32(ce32)
              resolve_ce32(cp, collation_data.ce32s[index], collation_data)

            when Collation::PREFIX_TAG, Collation::CONTRACTION_TAG
              # these need the input string to match against and are thus handled algorithmically
              CONTEXT_CE

            when Collation::FALLBACK_TAG
              FALLBACK_CE

            else
              raise "Unreachable"
          end
        end

        # if ces.is_a?(Array)
        #   ces.map do |ce|
        #     if ce < 0
        #       ce & -0xFFFF_FFFF_FFFF_FFFF
        #     else
        #       ce & 0xFFFF_FFFF_FFFF_FFFF
        #     end
        #   end
        # else
        #   ces
        # end
      end

      def chars_trie_class
        @chars_trie_class ||= requirements[:icu].get_class("com.ibm.icu.util.CharsTrie")
      end

      def collator_class
        @collator_class ||= requirements[:icu].get_class("com.ibm.icu.text.Collator")
      end

      def collation_loader_class
        @collation_loader_class ||= requirements[:icu].get_class("com.ibm.icu.impl.coll.CollationLoader")
      end

      def collation_settings_class
        @collation_settings_class ||= requirements[:icu].get_class("com.ibm.icu.impl.coll.CollationSettings")
      end

      def ulocale_class
        @ulocale_class ||= requirements[:icu].get_class("com.ibm.icu.util.ULocale")
      end

      def output_class
        @output_class ||= requirements[:icu].get_class("com.ibm.icu.util.Output")
      end

      def reorder_codes
        collator_class::ReorderCodes
      end

      def collation_data_bridge_class
        @collation_data_bridge_class ||= begin
          path = File.join(__dir__, "CollationDataBridge.class")
          requirements[:icu].load_class_from_file(path, "CollationDataBridge")
        end
      end

    end
  end
end
