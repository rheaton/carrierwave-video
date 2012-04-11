module CarrierWave
  module Video
    class FfmpegOptions
      attr_reader :watermark_path, :watermark_position, :watermark_pixels,
        :format, :resolution, :callbacks

      def initialize(format, options)
        @format = format.to_s
        @watermark = options[:watermark].present?
        @resolution = options[:resolution] || "640x360"
        @callbacks = options[:callbacks] || {}
        @logger = options[:logger]
        @unparsed = options

        if watermark?
          @watermark_path = options[:watermark][:path]
          @watermark_position = options[:watermark][:position].to_s || :bottom_right
          @watermark_pixels = options[:watermark][:pixels_from_edge] || 10
        end
      end

      def raw
        @unparsed
      end

      def logger(model)
        model.send(@logger) if @logger.present?
      end

      def encoder_options
        {preserve_aspect_ratio: :width}
      end

      def format_options
        format_options = case format
        when "mp4"
          {
            video_codec: 'libx264',
            audio_codec: 'libfaac',
            custom: "-b 1500k -vpre slow -vpre baseline -g 30 #{watermark_params}"
          }
        when "webm"
          {
            video_codec: 'libvpx',
            audio_codec: 'libvorbis',
            custom: "-b 1500k -ab 160000 -f webm -g 30 #{watermark_params}"
          }
        when "ogv"
          {
            video_codec: 'libtheora',
            audio_codec: 'libvorbis',
            custom: "-b 1500k -ab 160000 -g 30 #{watermark_params}"
          }
        else
          {}
        end
        { resolution: resolution }.merge(format_options)
      end

      def watermark?
        @watermark
      end

      def watermark_params
        return "" unless watermark?
        positioning = case watermark_position
                        when 'bottom_left'
                          "#{watermark_pixels}:main_h-overlay_h-#{watermark_pixels}"
                        when 'bottom_right'
                          "main_w-overlay_w-#{watermark_pixels}:main_h-overlay_h-#{watermark_pixels}"
                        when 'top_left'
                          "#{watermark_pixels}:#{watermark_pixels}"
                        when 'top_right'
                          "main_w-overlay_w-#{watermark_pixels}:#{watermark_pixels}"
                      end

        "-vf \"movie=#{watermark_path} [logo]; [in][logo] overlay=#{positioning} [out]\""
      end
    end
  end
end
