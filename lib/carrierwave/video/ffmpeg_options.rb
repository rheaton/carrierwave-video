module CarrierWave
  module Video
    class FfmpegOptions
      attr_reader :format, :resolution, :custom, :callbacks

      def initialize(format, options)
        @format = format.to_s
        @resolution = options[:resolution] || "640x360"
        @custom = options[:custom]
        @callbacks = options[:callbacks] || {}
        @logger = options[:logger]
        @unparsed = options
        @progress = options[:progress]

        @format_options = defaults.merge(options)
      end

      def raw
        @unparsed
      end

      def logger(model)
        model.send(@logger) if @logger.present?
      end

      def progress(model)
        lambda {|val| model.send(@progress, val)}
      end

      def encoder_options
        { preserve_aspect_ratio: :width }
      end

      # input
      def format_options
        @format_options
      end

      # output
      def format_params
        params = @format_options.dup
        params[:custom] = [params[:custom], watermark_params].compact.join(' ')
        params
      end

      def watermark?
        @format_options[:watermark].present?
      end

      def watermark_params
        return nil unless watermark?

        @watermark_params ||= begin
          path = @format_options[:watermark][:path]
          position = @format_options[:watermark][:position].to_s || :bottom_right
          margin = @format_options[:watermark][:pixels_from_edge] || @format_options[:watermark][:margin] || 10
          positioning = case position
                          when 'bottom_left'
                            "#{margin}:main_h-overlay_h-#{margin}"
                          when 'bottom_right'
                            "main_w-overlay_w-#{margin}:main_h-overlay_h-#{margin}"
                          when 'top_left'
                            "#{margin}:#{margin}"
                          when 'top_right'
                            "main_w-overlay_w-#{margin}:#{margin}"
                        end

          "-vf \"movie=#{path} [logo]; [in][logo] overlay=#{positioning} [out]\""
        end
      end

      private

        def defaults
          @defaults ||= { resolution: '640x360', watermark: {} }.tap do |h|
            case format
            when 'mp4'
              h[:video_codec] = 'libx264'
              h[:audio_codec] = 'libfaac'
              h[:custom] = '-qscale 0 -preset slow -g 30'
            when 'ogv'
              h[:video_codec] = 'libtheora'
              h[:audio_codec] = 'libvorbis'
              h[:custom] = '-b 1500k -ab 160000 -g 30'
            when 'webm'
              h[:video_codec] = 'libvpx'
              h[:audio_codec] = 'libvorbis'
              h[:custom] = '-b 1500k -ab 160000 -f webm -g 30'
            end
          end
        end
    end
  end
end
