= CarrierWave Video Converter

{<img src="https://secure.travis-ci.org/rheaton/carrierwave-video.png?branch=master" alt="Build Status" />}[http://travis-ci.org/rheaton/carrierwave-video]

This gem adds a video converter using ffmpeg and the streamio-ffmpeg rubygem.

= Installation

    gem install carrierwave-video

Using bundler:

    gem 'carrierwave-video'

= Usage

    class VideoUploader < CarrierWave::Uploader::Base
      include CarrierWave::Video

      process encode_video: [:mp4, callbacks: { after_transcode: :set_success } ]
    end

    class Video
      mount_uploader :file, VideoUploader

      def set_success(format, opts)
        self.success = true
      end
    end

= Possible Options

Pass in options to process:

    process encode_video: [:mp4, resolution: "200x200"]

Resolution passed to ffmpeg:
    resolution: "640x360"

Also, you can preserve initial video's aspect ratio by changing one of result's resolutions:
    preserve_aspect_ratio: :width
to change height of the video, depending on it's width (default value),
    preserve_aspect_ratio: :height
to change width of the video, depending on it's height, or
    preserve_aspect_ratio: false
to leave resolution unchanged

If you want to keep the same resolution:

Note: This only works with the edge version of streamio-ffmpeg (as of Feb 28, 2014) https://github.com/streamio/streamio-ffmpeg/issues/72

  resolution: :same

If you want to keep the same video bitrate:
  video_bitrate: :same

Watermark:
    watermark: {
      path: File.join(Rails.root, "directory", "file.png"),
      position: :bottom_right, # also: :top_right, :bottom_left, :bottom_right
      pixels_from_edge: 10
    }

Callbacks:
These are methods defined on the model. They will be run as part of the transcoding process.
Useful for notating failure and completion.
They will be called with the parameters sent to process.

    callbacks: {
      before_transcode: :method
      after_transcode: :method
      rescue: :method
      ensure: :method
    }

Logging:
    logger: :method   # returns object that behaves like Logger

    progress: :method # method that accepts a value of progress e.g. 0.2 (20%)
                      # from https://github.com/streamio/streamio-ffmpeg#transcoding

progress can take 1 or 3 arguments. With three arguments, it receives format, format_options, and the value of progress.
e.g. `def progress(format, format_options, progress)` would receive something like `progress(:mp4, {}, 0.2)`

Custom:
streamio-ffmpeg accepts custom params. You may pass these in but keep in mind the watermarking params will be appended if there were any.
  custom: %w(-b 1500k)

= Dynamic Configuration

    class VideoUploader < CarrierWave::Uploader::Base
      include CarrierWave::Video

      DEFAULTS = {
        watermark: {
          path: Rails.root.join('watermark-large.png')
        }
      }

      process :encode

      def encode
        encode_video(:mp4, DEFAULTS) do |movie, params|
          if movie.height < 720
            params[:watermark][:path] = Rails.root.join('watermark-small.png')
          end
        end
      end
    end

= OGG/OGV & Theora

If you want to transcode to OGV format, I recommend using ffmpeg2theora. It works better.
Support for this is built into this gem, but it is not as mature as the transcoding
support built into the streamio-ffmpeg gem. You will need to install the ffmpeg2theora binary.
http://v2v.cc/~j/ffmpeg2theora/

ffmpeg2theora does not have watermark support, so if you want a watermark, I recommend
building the theora file off previous version. I have not built in resolution or any other options
as I am just creating mine from a previous version (in the correct size/with watermark).
If you need support for this it shouldn't be too hard to add. (Use streamio-ffmpeg for inspiration)

Example:

    class VideoUploader < CarrierWave::Uploader::Base
      include CarrierWave::Video

      version :mp4 do
        process :encode_video => [:mp4, {...}]
      end

      version :ogv, :from_version => :mp4 do
        process :encode_ogv => [{ logger: logger_method, callbacks: {...}  }]
      end
    end

You do not need to pass in the format to the encode_ogv method (as it is always ogv).
The only options that do work are logger and callbacks. Others will be ignored.


= ffmpeg installation notes:

Installing with homebrew on OSX will get a nice configuration that works with this gem (including libx264 and libfaac for mp4's and libvorbis and libvpx for webm).
The default quality of the libtheora and libvorbix ogv defaults is poor, but installed with the default homebrew. As mentioned above, you can use ffmpeg2theora.

The default custom params for mp4 encoding use presets.
You can change the custom params to use whatever you want, but the presets are supposed to give a better video quality.
The preset files are here: http://www.mediasoftpro.com/aspnet-x264-presets.html
Depending on how you installed ffmpeg, you need to put them in the correct directory: http://ffmpeg.org/ffmpeg.html#Preset-files

= Upcoming and notes



* ffmpeg gives a confusing error if watermark file does not exist, raise in ruby
* error handling/checking (extract from streamio-ffmpeg gem's transcoder) for encode_ogv

*NOTE:*
For older versions of ffmpeg, the +-preset+ flag was called +-vpre+.  If you are using a version prior to 0.11, you must call carrierwave-video using the +custom+ option to change those flags.  Something along the lines of:

    encode_video(:mp4, :custom => %w(-qscale 0 -vpre slow -vpre baseline -g 30))

