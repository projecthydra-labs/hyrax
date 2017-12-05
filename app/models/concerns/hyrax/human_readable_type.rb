module Hyrax
  module HumanReadableType
    extend ActiveSupport::Concern

    module ClassMethods
      def human_readable_type
        default = @_human_readable_type || name.demodulize.titleize
        I18n.translate("activefedora.models.#{model_name.i18n_key}", default: default)
      end

      def human_readable_type=(val)
        @_human_readable_type = val
      end
      deprecation_deprecate :human_readable_type= => 'human_readable_type is deprecated. ' \
        'Set the i18n key for activefedora.models.#{model_name.i18n_key} instead. ' \
        'This will be removed in Hyrax 3'
    end

    def human_readable_type
      self.class.human_readable_type
    end
  end
end
