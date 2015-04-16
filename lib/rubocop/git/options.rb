module RuboCop
  module Git
    class Options
      class Invalid < StandardError; end

      HOUND_DEFAULT_CONFIG_FILE =
        File.expand_path('../../../../hound.yml', __FILE__)

      attr_accessor :config
      attr_reader   :cached, :hound, :rubocop, :auto_correct, :precommit

      def initialize(hash_options = nil)
        @config  = nil
        @cached  = false
        @hound   = false
        @rubocop = {}
        @commits = []
        @auto_correct = false
        @precommit = false

        from_hash(hash_options) if hash_options
      end

      def cached=(cached_)
        if cached_ && !@commits.empty?
          fail Invalid, 'cached and commit cannot be specified together'
        end
        @cached = !!cached_
      end

      def auto_correct=(auto_correct_)
        @auto_correct = !!auto_correct_
      end

      def precommit=(precommit_)
        @precommit = precommit_
      end

      def hound=(hound_)
        @hound = !!hound_
      end

      def rubocop=(rubocop_)
        unless rubocop_.is_a?(Hash)
          fail Invalid, "invalid rubocop: #{rubocop_.inspect}"
        end
        @rubocop = rubocop_
      end

      def commits=(commits)
        unless commits.is_a?(Array) && commits.length <= 2
          fail Invalid, "invalid commits: #{commits.inspect}"
        end
        if !commits.empty? && cached
          fail Invalid, 'cached and commit cannot be specified together'
        end
        @commits = commits
      end

      def config_file
        if hound
          HOUND_DEFAULT_CONFIG_FILE
        elsif config
          config
        elsif File.exist?(RuboCop::ConfigLoader::DOTFILE)
          RuboCop::ConfigLoader::DOTFILE
        else
          RuboCop::ConfigLoader::DEFAULT_FILE
        end
      end

      def commit_first
        @commits.length == 1 ? @commits.first + '^' : @commits.first
      end

      def commit_last
        @commits.last
      end

      private

      def from_hash(hash_options)
        hash_options = hash_options.dup
        %w(config cached hound rubocop commits autocorrect).each do |key|
          public_send("#{key}=", hash_options.delete(key))
        end
        unless hash_options.empty?
          fail Invalid, "invalid keys: #{hash_options.keys.join(' ')}"
        end
      end
    end
  end
end
