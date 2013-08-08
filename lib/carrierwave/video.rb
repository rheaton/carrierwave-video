require 'streamio-ffmpeg'
require 'carrierwave'
require 'carrierwave/video/ffmpeg_options'
require 'carrierwave/video/ffmpeg_theora'

module CarrierWave
  module Video
    extend ActiveSupport::Concern
    def self.ffmpeg2theora_binary=(bin)
      @ffmpeg2theora = bin
    end

    def self.ffmpeg2theora_binary
      @ffmpeg2theora.nil? ? 'ffmpeg2theora' : @ffmpeg2theora
    end

    module ClassMethods
      def encode_video(target_format, options={})
        process encode_video: [target_format, options]
      end

      def encode_ogv(opts={})
        process encode_ogv: [opts]
      end

    end

    def encode_ogv(opts)
      # move upload to local cache
      cache_stored_file! if !cached?

      tmp_path  = File.join( File.dirname(current_path), "tmpfile.ogv" )
      @options = CarrierWave::Video::FfmpegOptions.new('ogv', opts)

      with_trancoding_callbacks do
        transcoder = CarrierWave::Video::FfmpegTheora.new(current_path, tmp_path)
        transcoder.run(@options.logger(model))
        File.rename tmp_path, current_path
      end
    end

    def encode_video(format, opts={})
      # move upload to local cache
      cache_stored_file! if !cached?

      @options = CarrierWave::Video::FfmpegOptions.new(format, opts)
      tmp_path = File.join( File.dirname(current_path), "tmpfile.#{format}" )
      file = ::FFMPEG::Movie.new(current_path)

      if opts[:resolution] == :same
        @options.format_options[:resolution] = file.resolution
      end

      yield(file, @options.format_options) if block_given?

      progress = @options.progress(model)

      with_trancoding_callbacks do
        if progress
          file.transcode(tmp_path, @options.format_params, @options.encoder_options) {
              |value| progress.call(value)
          }
        else
          file.transcode(tmp_path, @options.format_params, @options.encoder_options)
        end
        File.rename tmp_path, current_path
      end
    end

    private
      def with_trancoding_callbacks(&block)
        callbacks = @options.callbacks
        logger = @options.logger(model)
        begin
          send_callback(callbacks[:before_transcode])
          setup_logger
          block.call
          send_callback(callbacks[:after_transcode])
        rescue => e
          send_callback(callbacks[:rescue])

          if logger
            logger.error "#{e.class}: #{e.message}"
            e.backtrace.each do |b|
              logger.error b
            end
          end

          raise CarrierWave::ProcessingError.new("Failed to transcode with FFmpeg. Check ffmpeg install and verify video is not corrupt or cut short. Original error: #{e}")
        ensure
          reset_logger
          send_callback(callbacks[:ensure])
        end
      end

      def send_callback(callback)
        model.send(callback, @options.format, @options.raw) if callback.present?
      end

      def setup_logger
        return unless @options.logger(model).present?
        @ffmpeg_logger = ::FFMPEG.logger
        ::FFMPEG.logger = @options.logger(model)
      end

      def reset_logger
        return unless @ffmpeg_logger
        ::FFMPEG.logger = @ffmpeg_logger
      end
  end
end
