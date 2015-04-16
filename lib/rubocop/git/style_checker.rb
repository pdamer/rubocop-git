module RuboCop::Git
# ref. https://github.com/thoughtbot/hound/blob/d2f3933/app/models/style_checker.rb
class StyleChecker
  def initialize(modified_files,
                 rubocop_options,
                 config_file,
                 custom_config = nil,
                 auto_correct = nil)
    @modified_files = modified_files
    @rubocop_options = rubocop_options
    @config_file = config_file
    @custom_config = custom_config
    @auto_correct = auto_correct
  end

  def violations
    file_violations = @modified_files.map do |modified_file|
      FileViolation.new(modified_file.filename, offenses(modified_file))
    end

    autocorrect(file_violations) if @auto_correct

    file_violations.select do |file_violation|
      file_violation.offenses.any?
    end
  end

  private

  def offenses(modified_file)
    violations = style_guide.violations(modified_file)
    violations_on_changed_lines(modified_file, violations)
  end

  def violations_on_changed_lines(modified_file, violations)
    violations.select do |violation|
      modified_file.relevant_line?(violation.line)
    end
  end

  def style_guide
    @style_guide ||= StyleGuide.new(@rubocop_options,
                                    @config_file,
                                    @custom_config)
  end

  def autocorrect(file_violations)
    file_violations.each do |file_violation|
      file_violation.offenses = file_violation.offenses.map do |offense|
        cop_klass =  RuboCop::Cop.const_get offense.cop_name.split('/').join('::')
        cop = cop_klass.new
        p offense
        p offense.location

        if cop.support_autocorrect?
          begin
            if cop.autocorrect(offense.location)
              buffer = Parser::Source::Buffer.new(file_violation.filename).read
              corrector = RuboCop::Cop::Corrector.new(buffer, cop.corrections)
              new_source = corrector.rewrite
              if new_source != buffer.source
                File.open(file_violation.filename, 'w') { |f| f.write(new_source) }
                RuboCop::Cop::Offense.new(offense.severity.code,
                                          offense.location,
                                          offense.message,
                                          offense.cop_name, true)

              else
                offense
              end
            end
          rescue RuboCop::Cop::CorrectionNotPossible
            offense
          end
        else
          offense
        end
      end
    end
  end
end
end
