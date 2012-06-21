module CarrierWave
  module Video
    class FfmpegTheora
      attr_reader :input_path, :output_path
      def initialize(input_file_path, output_file_path)
        @input_path = input_file_path
        @output_path = output_file_path
      end

      def run(logger)
        cmd = "#{CarrierWave::Video.ffmpeg2theora_binary} #{input_path} -o #{output_path}"
        outputs = []

        Open3.popen3(cmd) do |stdin, stdout, stderr|
          stderr.each("r") do |line|
            outputs << line
          end
        end

        logger.error(outputs.inspect)
      end
    end
  end
end
