library(dplyr)
library(Hmisc)
library(igraph)
library(RColorBrewer)
library(stringr)

# constants
CT_NAMES = "./Finucane2015_ct_names.txt"
CT_Q_THRESHOLD = 0.01
MIN_VERTEX_SIZE = 6
MAX_VERTEX_SIZE = 20
MAX_EDGE_WIDTH = 10

################################################################################
args = commandArgs(trailingOnly=T)
if (identical(args, character(0))) {
  args = str_c("./input_example/", c("input_ct.txt", "traitlist.txt"))
}
ct_fname = args[1]
traitlist_fname = args[2]

################################################################################
# load data
ct = read.table(ct_fname, T, sep='\t', as.is = T)
traitlist = read.table(traitlist_fname, T, sep = '\t', as.is = T, quote = '', fileEncoding='utf-8', comment.char="")

ct_names = read.table(CT_NAMES, header = T, as.is = T, sep = '\t')
cols = data.frame(category = c("Adrenal_Pancreas","CNS","Cardiovascular","Connective_Bone","GI","Hematopoietic","Kidney","Liver","SkeletalMuscle","Other"),
                  color = c("#FFE014","#3B37C2","#BE5BC7","#D3FF5B","#80B5FF","#31B54A","#8A6F43","#F8480C","#FF80AE","#7F7F7F"))
ct_names = merge(ct_names, cols, by = "category", all.x = T)
ct_names$color = as.character(ct_names$color)

ct = merge(ct, ct_names, by = "cell_type_clean")

################################################################################
# construct ct graph
ct_sig = ct %>% filter(Coefficient_q < CT_Q_THRESHOLD) %>%
                group_by(cell_type_clean2, trait) %>%
                summarise(n = n(), q = min(Coefficient_q))

rel_ct = data.frame(from = ct_sig$cell_type_clean2,
                    to = ct_sig$trait,
                    directed = T,
                    weight = -log10(ct_sig$q),
                    q = ct_sig$q,
                    type = "ct")
rel_ct$weight = rel_ct$weight / max(rel_ct$weight)
g = graph.data.frame(rel_ct, directed=T)

################################################################################
# layout
l = layout_with_fr(g)
l = norm_coords(l)
V(g)$x = l[,1]
V(g)$y = l[,2]


################################################################################
# vertex visual
is_trait_v = V(g)$name %in% traitlist$TRAIT
V(g)$color = "grey90"
V(g)$color[is_trait_v] = traitlist$COLOR[match(V(g)$name[is_trait_v], traitlist$TRAIT)]
V(g)$color[!is_trait_v] = ct_names$color[match(V(g)$name[!is_trait_v], ct_names$cell_type_clean2)]
V(g)$shape = ifelse(is_trait_v, "circle", "square")
V(g)$label = V(g)$name
V(g)$label.color = "black"
V(g)$label.font = ifelse(is_trait_v, 2, 4)
V(g)$label.family = "sans"
V(g)$label.cex = 0.7
V(g)$label.degree = pi/2
V(g)$size = 6

ct_sig_trait_n = ct %>% filter(Coefficient_q < CT_Q_THRESHOLD) %>% group_by(trait) %>% count()
n_v_cls = 16;
v_cls_ct = cut2(ct_sig_trait_n$n[match(V(g)$name[is_trait_v], ct_sig_trait_n$trait)], g = n_v_cls)
v_size_ct = seq(MIN_VERTEX_SIZE, MAX_VERTEX_SIZE, length.out = n_v_cls)[match(v_cls_ct, levels(v_cls_ct))]
V(g)$size[is_trait_v] = v_size_ct

ct_sig_cell_n = ct %>% filter(Coefficient_q < CT_Q_THRESHOLD) %>% group_by(cell_type_clean2) %>% summarise(n = length(unique(trait)))
n_v_cls = 16;
v_cls_ct = cut2(ct_sig_cell_n$n[match(V(g)$name[!is_trait_v], ct_sig_cell_n$cell_type_clean2)], g = n_v_cls)
v_size_ct = seq(MIN_VERTEX_SIZE, MAX_VERTEX_SIZE, length.out = n_v_cls)[match(v_cls_ct, levels(v_cls_ct))]
V(g)$size[!is_trait_v] = v_size_ct


################################################################################
# edge visual
ct_cols = c("#F7F7F7", brewer.pal(5, "Blues"), c("seagreen", "gold", "deeppink"))
edge_cls_ct = cut2(-log10(ct_sig$q), cuts = c(seq(0, -log10(0.05), length=6), seq(2, ceiling(max(-log10(ct_sig$q))), by=1)))
edge_color_ct = ct_cols[match(edge_cls_ct, levels(edge_cls_ct))]

edge_width = -log10(ct_sig$q)
edge_width[edge_width > MAX_EDGE_WIDTH] = MAX_EDGE_WIDTH

E(g)$color = edge_color_ct
E(g)$width = edge_width
E(g)$curved = .2
E(g)$arrow.size = -log10(ct_sig$q)/4


################################################################################
# save images & graph
ts = as.numeric(Sys.time())
out_fname = sprintf("./output/network_ct_%.0f", ts)
png(str_c(out_fname, ".png"), width = 9, height = 9, units = "in", res = 300)
plot(g, rescale = F)
dev.off()

pdf(str_c(out_fname, ".pdf"), width = 9, height = 9)
plot(g, rescale = F)
dev.off()

save(list = c("g", "l"), file = str_c(out_fname, ".RData"))
