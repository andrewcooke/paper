
require("/home/andrew/project/paper/paper.jl")

# here we go...

const width = 620
const n_points = 2000000

output, close = cairo_pdf("paper.pdf", width)
paper = combine_folds(n_folds, Task(random_folds), undistorted)
pdriver(n_points, paper, output)
close()
