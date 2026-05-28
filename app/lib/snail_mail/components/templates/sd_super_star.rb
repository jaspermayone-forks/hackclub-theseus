# frozen_string_literal: true

module SnailMail
  module Components
    module Templates
      class SdSuperStar < HalfLetterComponent
        IMAGES = %w(wizard.png hotdogcat.jpg magic_smoke.png)

        def self.abstract? = false

        def address_font = "gohu"

        def self.template_name = "Stardance Super Star"

        def self.template_size = :half_letter

        def self.show_on_single? = false

        def render_front
          image(
            image_path(IMAGES.sample),
            at: [410, bounds.bottom + 200],
            valign: :top,
            width: 150
          )

          meta = letter.metadata || {}
          project = (proj = meta["project"]).present? ? "#{proj} " : nil
          reviewer = meta["reviewer"].presence || "your secret admirer"
          text = <<~EOM
            Hey, #{letter.address&.first_name&.titleize},

            We wanted to tell the star of the day, (that's you!), that your project #{project}really brightened up the sky at HQ!

            We love seeing people shoot for the stars, and you're shining brighter than ever!

            Many thanks & keep hacking!

            <3 ~#{reviewer} @ Mission Control





            tl;dr: TS is out of this world!
          EOM

          font "gohu" do text_box text, at: [15, bounds.top-15], width: bounds.right - 200 - 20, size: 14 end
        end

        def render_back
          super
        end
      end
    end
  end
end
