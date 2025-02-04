using ImageView, TestImages, ImageCore, ImageView.Observables,
      GtkObservables, Gtk, IntervalSets
using Test
using AxisArrays: AxisArrays, AxisArray, Axis

@testset "1d" begin
    img = rand(N0f8, 5)
    guidict = imshow_now(img)
    win = guidict["gui"]["window"]
    destroy(win)
end

@testset "Aspect ratio" begin
    img = rand(N0f8, 20, 20)
    guidict = imshow_now(img)
    win, frame = guidict["gui"]["window"], guidict["gui"]["frame"]
    @test isa(frame, Gtk.GtkAspectFrameLeaf)
    zr = guidict["roi"]["zoomregion"]

    @test get_gtk_property(frame, :ratio, Float32) == 1.0
    zr[] = (1:20, 9:10)
    @test zr[].currentview.x == 9..10
    sleep(0.1)  # allow the Gtk event loop to run
    @test get_gtk_property(frame, :ratio, Float32) ≈ 0.1
    zr[] = (9:10, 1:20)
    Gtk.showall(win)
    sleep(0.1)
    @test get_gtk_property(frame, :ratio, Float32) ≈ 10.0

    destroy(win)

    guidict = imshow_now(img, aspect=:none)
    win, frame = guidict["gui"]["window"], guidict["gui"]["frame"]
    @test isa(frame, Gtk.GtkFrameLeaf)
    destroy(win)
end

# image display
@testset "Image display" begin
    img_n0f8 = rand(N0f8, 3,3)
    imsd = imshow_now(img_n0f8; name="N0f8")
    @test get_gtk_property(imsd["gui"]["window"], :title, String) == "N0f8"

    img_n0f16 = rand(N0f16, 3,3)
    imshow_now(img_n0f16; name="N0f16")

    img_rgb = rand(RGB{N0f8}, 3, 3)
    imshow_now(img_rgb; name="RGB{N0f8}")

    img_int = rand(Int, 3,3)
    imshow_now(img_int; name="Int")

    img_float16 = rand(Float16, 3,3)
    imshow_now(img_float16; name="Float16")

    img_float32 = rand(Float32, 3,3)
    img_float32[1,1] = NaN
    img_float32[2,1] = Inf
    img_float32[3,1] = -5
    imshow_now(img_float32; name="Float32")

    img_float64 = rand(Float64, 3,3)
    imshow_now(img_float64; name="Float64")

    img_nan = fill(NaN, (3,3))
    imshow_now(img_nan; name="NaN")

    img_rgbfloat = rand(RGB{Float32}, 3, 3)
    imshow_now(img_rgbfloat; name="RGB{Float32}")

    img = testimage("lighthouse")
    hlh = imshow_now(img, name="Lighthouse")

    # a large image
    img = testimage("earth")
    hbig = imshow_now(img, name="Earth")
    win = hbig["gui"]["window"]
    w, h = size(win)
    ws, hs = screen_size(win)
    !Sys.iswindows() && @test w <= ws && h <= hs

    # a very large image
    img = rand(N0f8, 10000, 15000)
    hbig = imshow_now(img, name="VeryBig"; canvassize=(500,500))
    sleep(0.1)  # some extra sleep for this big image
    cvs = hbig["gui"]["canvas"];
    @test Graphics.height(getgc(cvs)) <= 500
    @test Graphics.width(getgc(cvs)) <= 500
end

@testset "imshow!" begin
    img = testimage("mri")
    guidict = imshow(img[:,:,1])
    c = guidict["gui"]["canvas"]
    ImageView.imshow!(c, img[:,:,2])

    imgsig = Observable(img[:,:,1])
    imshow(c, imgsig)
    imgsig[] = img[:,:,8]
end

@testset "Orientation" begin
    img = [1 2; 3 4]
    guidict = imshow_now(img)
    @test parent(guidict["roi"]["image roi"][]) == [1 2; 3 4]
    guidict = imshow_now(img, flipy=true)
    @test parent(guidict["roi"]["image roi"][]) == [3 4; 1 2]
    guidict = imshow_now(img, flipx=true)
    @test parent(guidict["roi"]["image roi"][]) == [2 1; 4 3]
    guidict = imshow_now(img, flipx=true, flipy=true)
    @test parent(guidict["roi"]["image roi"][]) == [4 3; 2 1]
end

@testset "Mapping errors" begin
    # Create a colortype with missing methods
    struct OneChannelColor{T} <: Color{T,1}
        val1::T
    end
    img = [OneChannelColor(0) OneChannelColor(1);
           OneChannelColor(2) OneChannelColor(3);
    ]
    @test_throws ErrorException("got unsupported eltype Union{} in preparing the constrast") imshow(img, CLim(0, 1))

    struct MyChar <: AbstractChar
        c::Char
    end
    ImageView.prep_contrast(canvas, @nospecialize(img::Observable), clim::Observable{CLim{MyChar}}) = img
    img = MyChar['a' 'b'; 'c' 'd']
    @test_throws ErrorException("got unsupported eltype MyChar in creating slice") imshow(img, CLim{MyChar}('a', 'b'))
end

if Gtk.libgtk_version >= v"3.10"
    # These tests use the player widget
    @testset "Multidimensional" begin
        # Test that we can use positional or named axes with AxisArrays
        img = AxisArray(rand(3, 5, 2), :x, :y, :z)
        guin = imshow_now(img; name="AxisArray Named")
        @test isa(guin["roi"]["slicedata"].axs[1], Axis{:z})
        guip = imshow_now(img; axes=(1,2), name="AxisArray Positional")
        @test isa(guip["roi"]["slicedata"].axs[1], Axis{3})
        guip2 = imshow_now(img; axes=(1,3), name="AxisArray Positional")
        @test isa(guip2["roi"]["slicedata"].axs[1], Axis{2})

        ## 3d images
        img = testimage("mri")
        hmri = imshow_now(img; name="P,R view")
        @test isa(hmri["roi"]["slicedata"].axs[1], Axis{:S})

        # Use a custom CLim here because the first slice is not representative of the intensities
        hmrip = imshow_now(img, Observable(CLim(0.0, 1.0)), axes=(:S, :P), name="S,P view")
        @test isa(hmrip["roi"]["slicedata"].axs[1], Axis{:R})
        hmrip["roi"]["slicedata"].signals[1][] = 84

        ## Two coupled images
        mriseg = RGB.(img)
        mriseg[img .> 0.5] .= colorant"red"
        # version 1
        guidata = imshow_now(img, axes=(1,2))
        zr = guidata["roi"]["zoomregion"]
        slicedata = guidata["roi"]["slicedata"]
        guidata2 = imshow_now(mriseg, nothing, zr, slicedata)
        @test guidata2["roi"]["zoomregion"] === zr

        # version 2
        zr, slicedata = roi(img, (1,2))
        gd = imshow_gui((200, 200), (1,2); slicedata=slicedata)
        guidata1 = imshow(gd["frame"][1,1], gd["canvas"][1,1], img, nothing, zr, slicedata)
        guidata2 = imshow(gd["frame"][1,2], gd["canvas"][1,2], mriseg, nothing, zr, slicedata)
        Gtk.showall(gd["window"])
        sleep(0.01)
        @test guidata1["zoomregion"] === guidata2["zoomregion"] === zr

        # imlink
        gd = imlink(img, mriseg)
        Gtk.showall(gd["window"])
        sleep(0.01)
        @test gd["guidata"][1]["zoomregion"] === gd["guidata"][2]["zoomregion"]
    end

    @testset "Non-AbstractArrays" begin
        include("cone.jl")
    end
end

nothing
