library(dplyr)
library(Hmisc)
library(igraph)
library(RColorBrewer)
library(stringr)

# constants
RG_Q_THRESHOLD = 0.05
MIN_VERTEX_SIZE = 6
MAX_VERTEX_SIZE = 20
MAX_EDGE_WIDTH = 10

################################################################################
args = commandArgs(trailingOnly=T)
if (identical(args, character(0))) {
  args = str_c("./input_example/", c("input_rg.txt", "traitlist.txt"))
}
rg_fname = args[1]
traitlist_fname = args[2]


################################################################################
# load data
rg = read.table(rg_fname, T, sep='\t', as.is = T)
traitlist = read.table(traitlist_fname, T, sep = '\t', as.is = T, quote = '', fileEncoding='utf-8', comment.char="")


################################################################################
# construct rg graph
rg_sig = rg %>% filter(q < RG_Q_THRESHOLD)
rel_rg = data.frame(from = rg_sig$p1,
                    to = rg_sig$p2,
                    directed = F,
                    weight = abs(rg_sig$rg),
                    q = rg_sig$q,
                    type = "rg")
g = graph.data.frame(rel_rg, directed=F)


################################################################################
# layout
l = layout_with_fr(g)
l = norm_coords(l)
V(g)$x = l[,1]
V(g)$y = l[,2]


################################################################################
# vertex visual
V(g)$color = traitlist$COLOR[match(V(g)$name, traitlist$TRAIT)]
V(g)$shape = "circle"
V(g)$label = V(g)$name
V(g)$label.color = "black"
V(g)$label.font = 2
V(g)$label.family = "sans"
V(g)$label.cex = 0.7
V(g)$label.degree = pi/2

# duplicate lines
tmp = rg
tmp$p1 = rg$p2
tmp$p2 = rg$p1
tmp$p1_category = rg$p2_category
tmp$p2_category = rg$p1_category
rg_dup = rbind(rg, tmp)

rg_sig_n = rg_dup %>% filter(q < RG_Q_THRESHOLD) %>% group_by(p1) %>% count()
n_v_cls = diff(range(rg_sig_n$n))+1;
v_cls_rg = cut2(rg_sig_n$n[match(V(g)$name, rg_sig_n$p1)], g = n_v_cls)
v_size_rg = seq(MIN_VERTEX_SIZE, MAX_VERTEX_SIZE, length.out = n_v_cls)[match(v_cls_rg, levels(v_cls_rg))]
V(g)$size = v_size_rg

################################################################################
# edge visual
rg_cols = colorRampPalette(c("#67001F", "#B2182B", "#D6604D", "#F4A582",
                             "#FDDBC7", "#FFFFFF", "#D1E5F0", "#92C5DE",
                             "#4393C3", "#2166AC", "#053061"))(200)
edge_cls_rg = cut2(rg_sig$rg, cuts = seq(-1, 1, length.out = 201))
edge_color_rg = rg_cols[match(edge_cls_rg, levels(edge_cls_rg))]

edge_width = -log10(rg_sig$q)
edge_width[edge_width > MAX_EDGE_WIDTH] = MAX_EDGE_WIDTH

E(g)$color = edge_color_rg
E(g)$width = edge_width
E(g)$curved = .2
E(g)$arrow.size = .5


################################################################################
# save images & graph

ts = as.numeric(Sys.time())
out_fname = sprintf("./output/network_rg_%.0f", ts)
png(str_c(out_fname, ".png"), width = 9, height = 9, units = "in", res = 300)
plot(g, rescale = F)
dev.off()

pdf(str_c(out_fname, ".pdf"), width = 9, height = 9)
plot(g, rescale = F)
dev.off()

save(list = c("g", "l"), file = str_c(out_fname, ".RData"))

