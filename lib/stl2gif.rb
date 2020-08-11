require 'stl'
require 'mustache'
require 'rmagick'
require 'stl2gif/version'
require 'stl2gif/point'
require 'stl2gif/triangle'
require 'stl2gif/mesh'

module Stl2gif
  class Stl
    attr_reader :file, :options
    attr_accessor :mesh, :frames

    # SEC-WARN: no option input can be user provided
    def initialize(file, options = {})
      @file = file
      @mesh = load_mesh
      @frames = []

      @options = {}
      @options[:template] = options[:template] || File.expand_path('../stl2gif/template.pov', __FILE__)
      @options[:width] = options[:width] || '300'
      @options[:height] = options[:height] || '300'
      @options[:step] = options[:step] || 8
    end

    def to_pov
      mesh.to_pov
    end

    def load_mesh
      Mesh.new(load_stl)
    end

    def load_stl
      STL.read(file)
    end

    # rotation: angle in radians (pi radians is half a turn)
    def render_frame(rotation)
      Tempfile.create 'pov' do |pov|
        pov.write(Mustache.render(template, modelData: to_pov, phi: rotation))
        pov.flush

        frame = Tempfile.new ['frame', '.png']

        system("povray -i#{pov.path} +FN +W#{options[:width]} "+
          "+H#{options[:height]} -o#{frame.path} +Q9 +AM1 +A +UA")

        frames << frame
      end
    end

    def template
      File.read(options[:template])
    end

    def generate_frames
      for i in 0..options[:step]*2-1
        render_frame Math::PI * i / options[:step]
      end
    end

    def to_png(basename)
      begin
        rotation = Math::PI * 2 / options[:step]
        png_file = Tempfile.create 'pov' do |pov|
          pov.write(Mustache.render(template, modelData: to_pov, phi: rotation))
          pov.flush

          frame = Tempfile.new ['frame', '.png']

          system("povray -i#{pov.path} +FN +W#{options[:width]} "+
            "+H#{options[:height]} -o#{frame.path} +Q9 +AM1 +A +UA")
          frame
        end
      ensure
      end
      png_file
    end

    def to_gif(basename)
      begin
        animation = Magick::ImageList.new *frames.map(&:path)
        animation.delay = 16
        gif_file = Tempfile.new [basename, '.gif']
        animation.write(gif_file.path)
      ensure
        frames.each do |f|
          f.close
          f.unlink
        end
      end
      gif_file
    end
  end
end
