module Spree
  module TaxonDecorator
    def self.prepended(base)
      base.after_create :update_temp_permalink_to_id
      base.after_destroy :touch_parent_on_destroy
    end

    def set_permalink
      self.permalink = generate_slug
    end

    private
    def generate_slug
      if new_record?
        uuid_for_friendly_id
      else
        if parent.present?
          [ parent.permalink, self.id.to_s ].join('/')
        else
          self.id.to_s
        end
      end
    end

    def update_temp_permalink_to_id
      update_column(:permalink, self.id.to_s)
    end

    def touch_parent_on_destroy
      # Touch parent and all ancestors when a taxon is destroyed to invalidate cache
      if parent.present?
        parent.touch
        parent.ancestors.update_all(updated_at: Time.current)
      end
      # Also touch taxonomy
      taxonomy.try!(:touch)
    end
  end
end

# Decoratorを適用
Spree::Taxon.prepend(Spree::TaxonDecorator)
