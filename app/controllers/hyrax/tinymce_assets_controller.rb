# frozen_string_literal: true

module Hyrax
  class TinymceAssetsController < ApplicationController
    def create
      authorize! :create, TinymceAsset
      image = TinymceAsset.create params.permit(:file)

      render json: {
        image: {
          url: image.file.url
        }
      }, content_type: "text/html"
    end
  end
end
