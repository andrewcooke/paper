
# 0 is black, 1 is white
# the paper extends from (0,0) to (1,1)


# the underlying image is a function from position and incident light to
# brightness.  the need for the light is something of a hack - it allows
# us to calculate the effect of folds on brightness even when we're
# still unsure whether we're evaluating the brightness of the paper (or
# are outside, in the background).

const border_shadow = 0.005
const border = 0.05  # less than shadow as entire image shrinks from folds
const plain_shade = 0.5

function to_bottom_corner(x)
    if 0 < x < 1
        return 0
    elseif x > 1
        return 1 - x
    else
        return x
    end
end

function undistorted(xy, light)
    x, y = viewport(xy)
    if 0 < x < 1 && 0 < y < 1
        return min(1, max(0, light))
    elseif x < 0 || y < 0
        return 1
    else
        x = to_bottom_corner(x)
        y = to_bottom_corner(y)
        r = sqrt(x^2 + y^2)
        return min(1, r / border_shadow)
    end
end


# this transform shifts the paper (originally also in the unit square)
# and border (originally outside) into the unit square (it just makes 
# things neater if we can use rand() at the top level).

function viewpoint(x)
    return x * (1 + 2 * border) - border
end

function viewport(xy)
    x, y = xy
    return (viewpoint(x), viewpoint(y))
end


# now the meat.  given a fold (position and angle), transform the x, y
# coordinates and the incident light.  these are just nice-looking
# approximations - there's no real physics here.

function distance(xy, fold)
    x, y = xy
    (p, q), theta = fold
    return (x - p) * sin(theta) - (y - q) * cos(theta)
end

const n_folds = 200
const fold_width = 0.04
const fold_shift = 0.15 / n_folds
const fold_grey = 0.15

function normalize(d)
    d = d / fold_width
    if d > 1
        return 1
    elseif d < -1
        return -1
    else
        return sign(d) * abs(d) ^ 1.5
    end
end

function shift(xy, theta, d)
    x, y = xy
    return (x + d * fold_shift * sin(theta), y - d * fold_shift * cos(theta))
end

function shade(g, theta, d)
    return g * (1 + (1 - abs(d)) * sign(d) * cos(theta + pi/3) * fold_grey)
end


# a stream of random folds.

function random_folds()
    while true
        produce(((rand(), rand()), pi * rand()))
    end
end


# take 'n' folds from the stream, and an underlying function (the paper)
# and create a new function that accumulates the effect of all the folds.
# an alternative would be to make an explicit iteration over the folds
# (i have no idea which is faster, but this seems neater).

function combine_folds(n, folds, base)
    if n == 0
        return base
    else
        fold = consume(folds)
        pq, theta = fold
        function wrapped(xy, light)
            d = normalize(distance(xy, fold))
            xy = shift(xy, theta, d)
            return base(xy, shade(light, theta, d))
        end
        return combine_folds(n-1, folds, wrapped)
    end
end


# to render the image we evaluate it and random points.

typealias Point (Float64, Float64)
typealias Result (Point, Float64)

function random_point()
    return (rand(), rand())
end

function random_points()
    while true
        produce(random_point())
    end
end

function take(n, seq)
    function inner()
        for i = 1:n
            produce(consume(seq))
        end
    end
    return Task(inner)
end

const block_size = 10000

function block_eval(seed, image)
    a = Array(Result, block_size)
    srand(seed)
    for i = 1:block_size
        point = random_point()
        a[i] = (point, image(point, plain_shade))
    end
    return a
end

function driver(n, image, output)
    blocks = div(n, block_size)
    for block in map(seed -> block_eval(seed, image), 1:blocks)
        for result in block
            output(result...)
        end
    end
end

function pdriver(n, image, output)
    blocks = div(n, block_size)
    for block in pmap(seed -> block_eval(seed, image), 1:blocks)
        for result in block
            output(result...)
        end
    end
end


# testing

function print_output(xy, g)
    x, y = xy
    println("$x $y $g")
end

#driver(20, undistorted, print_output)


# output to cairo pdf

using Cairo
const line_width = 0.5

function set_line_cap(ctx::CairoContext, style)
    ccall((:cairo_set_line_cap, "libcairo"), Void, (Ptr{Void},Int), ctx.ptr, style)
end

function cairo_pdf(file, size)
    s = CairoPDFSurface(file, size, size)
    c = CairoContext(s)
#    set_line_width(c, line_width)
    set_line_cap(c, 1)
    set_source_rgb(c, 0, 0, 0)
    function output(xy, g)
        if true || g < rand()
#            set_source_rgb(c, g, g, g)
            set_line_width(c, line_width * (1 - g))
            x, y = xy
            move_to(c, x * size, y * size)
            close_path(c)
#            rel_line_to(c, line_width/sqrt(2), line_width/sqrt(2))
            stroke(c)
        end
    end
    for x = 0:1
        for y = 0:1
            output((x,y), 0)
        end
    end
    function close()
        stroke(c)
        finish(s)
    end
    return (output, close)
end

