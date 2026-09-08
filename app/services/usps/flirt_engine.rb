module USPS
  # First-Class Letter Inverse Rating Toolkit
  class FLIRTEngine
    LETTER_WEIGHTS = [1.0, 2.0, 3.0, 3.5]
    FLAT_WEIGHTS = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0]

    class << self
      def desired_price(type, weight, country, non_machinable = false)
        PricingEngine.fcmi_price(type, weight, country, non_machinable)
      end

      def metered_price(type, weight, non_machinable = false)
        PricingEngine.metered_price(type, weight, non_machinable)
      end

      def stamp_price(type, weight, non_machinable = false)
        PricingEngine.domestic_stamp_price(type, weight, non_machinable)
      end

      def closest_us_price(fcmi_rate)
        best_option = nil
        best_price = Float::INFINITY

        LETTER_WEIGHTS.each do |weight|
          [false, true].each do |non_machinable|
            price = PricingEngine.metered_price(:letter, weight, non_machinable)
            if price >= fcmi_rate && price < best_price
              best_price = price
              best_option = {
                processing_category: :letter,
                weight: weight,
                non_machinable: non_machinable
              }
            end
          end
        end

        FLAT_WEIGHTS.each do |weight|
          price = PricingEngine.metered_price(:flat, weight)
          if price >= fcmi_rate && price < best_price
            best_price = price
            best_option = {
              processing_category: :flat,
              weight: weight,
              non_machinable: false
            }
          end
        end

        raise ArgumentError, "can't figure out how to make $#{fcmi_rate} out of US rates, gotta use stamps instead :-(" unless best_option
        best_option.merge(difference: best_price - fcmi_rate, price: best_price)
      end
    end
  end
end
