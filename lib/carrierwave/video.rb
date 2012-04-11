require 'streamio-ffmpeg'
require 'carrierwave'
require 'carrierwave/video/ffmpeg_options'

module CarrierWave
  module Video
    extend ActiveSupport::Concern
    module ClassMethods
      def encode_video(target_format, options={})
        process encode_video: [target_format, options]
      end
    end

    def encode_video(format, opts={})
      # move upload to local cache
      cache_stored_file! if !cached?

      options = CarrierWave::Video::FfmpegOptions.new(format, opts)
      tmp_path  = File.join( File.dirname(current_path), "tmpfile.#{format}" )


      with_trancoding_callbacks(opts) do
        file = ::FFMPEG::Movie.new(current_path)
        file.transcode(tmp_path, options.format_options, options.encoder_options)
        File.rename tmp_path, current_path
      end
    end

    private
      def with_trancoding_callbacks(opts, &block)
        callbacks = opts[:callbacks] || {}
        logger_opt = opts[:logger]
        begin
          send_callback(callbacks[:before_transcode])
          setup_logger(logger_opt)
          block.call
          send_callback(callbacks[:after_transcode])
        ensure
          reset_logger
          send_callback(callbacks[:ensure])
        end
      end

      def send_callback(callback)
        model.send(callback) if callback.present?
      end

      def setup_logger(opt)
        return unless opt.present?
        @ffmpeg_logger = ::FFMPEG.logger
        ::FFMPEG.logger = model.send(opt)
      end

      def reset_logger
        return unless @ffmpeg_logger
        ::FFMPEG.logger = @ffmpeg_logger
      end
  end
end
