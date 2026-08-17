# frozen_string_literal: true

module Spree
  module PageSections
    module FeaturedPostsDecorator
      def retrieve_posts
        Spree::Post.where(store: store)
                   .where("published_at < ?", Time.zone.now.utc)
                   .order(id: :desc)
                   .includes(:post_category)
                   .limit(preferred_max_posts_to_show)
      end
    end
  end
end

::Spree::PageSections::FeaturedPosts.prepend(Spree::PageSections::FeaturedPostsDecorator)
