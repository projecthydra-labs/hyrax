require 'rails/generators'
require 'rails/generators/model_helpers'

class Hyrax::WorkResourceGenerator < Rails::Generators::NamedBase
  # ActiveSupport can interpret models as plural which causes
  # counter-intuitive route paths. Pull in ModelHelpers from
  # Rails which warns users about pluralization when generating
  # new models or scaffolds.
  include Rails::Generators::ModelHelpers

  source_root File.expand_path('../templates', __FILE__)

  argument :attributes, type: :array, default: [], banner: 'field:type field:type'

  def banner
    if revoking?
      say_status("info", "DESTROYING VALKYRIE WORK MODEL: #{class_name}", :blue)
    else
      say_status("info", "GENERATING VALKYRIE WORK MODEL: #{class_name}", :blue)
    end
  end

  def create_controller
    template('controller.rb.erb', File.join('app/controllers/hyrax', class_path, "#{plural_file_name}_controller.rb"))
  end

  def create_model
    template('work.rb.erb', File.join('app/models/', class_path, "#{file_name}.rb"))
  end

  def create_model_spec
    template('work_spec.rb.erb', File.join('spec/models/', class_path, "#{file_name}_spec.rb")) if
      rspec_installed?
  end

  def create_indexer
    template('indexer.rb.erb', File.join('app/indexers/', class_path, "#{file_name}_indexer.rb"))
  end

  def create_actor
    template('actor.rb.erb', File.join('app/actors/hyrax/actors', class_path, "#{file_name}_actor.rb"))
  end

  def create_views
    create_file File.join('app/views/hyrax', class_path, "#{plural_file_name}/_#{file_name}.html.erb") do
      "<%# This is a search result view %>\n" \
      "<%= render 'catalog/document', document: #{file_name}, document_counter: #{file_name}_counter  %>\n"
    end
  end

  def create_view_spec
    return unless rspec_installed?
    template('work.html.erb_spec.rb.erb',
             File.join('spec/views/', class_path, "#{plural_file_name}/_#{file_name}.html.erb_spec.rb"))
  end

  private

    def rspec_installed?
      defined?(RSpec) && defined?(RSpec::Rails)
    end

    def revoking?
      behavior == :revoke
    end
end
