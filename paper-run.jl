
require("/home/andrew/project/paper/paper.jl")

# here we go...

const width = 4000
const n_points = 10000000

output, close = cairo_pdf("paper.pdf", width)
paper = combine_folds(n_folds, Task(random_folds), undistorted)
driver(n_points, paper, output)
close()
