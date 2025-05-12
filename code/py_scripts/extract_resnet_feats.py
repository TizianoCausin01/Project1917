# %%
# /Users/tizianocausin/Desktop/1917_py_env/bin/activate
# %%
import torch
import cv2
import torchvision.transforms as transforms
import matplotlib.pyplot as plt
from torchvision import models
from torchvision.models import ResNet18_Weights
import numpy as np
import h5py

resnet18 = models.resnet18(weights=True).eval()
preprocess = transforms.Compose(
    [
        transforms.ToPILImage(),
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.3806, 0.4242, 0.3794], std=[0.2447, 0.2732, 0.2561]
        ),  # Normalization for pretrained model
    ]
)
weights = ResNet18_Weights.DEFAULT
categories = weights.meta["categories"]
path2vid = "/Volumes/TIZIANO/stimuli/Project1917_movie_part3_24Hz.mp4"
reader = cv2.VideoCapture(path2vid)
layers = ["layer1", "layer2", "layer3", "layer4", "fc"]
output_len = [200704, 100352, 50176, 25088]
rand_idx = []
for len_repr in output_len:
    rand_idx.append(
        np.random.choice(np.arange(len_repr - 1), size=len_repr // 50, replace=False)
    )
rand_idx.append(np.arange(1000))  # artificially takes all the logits of the fc


def wrapper_hook(layer, rand_idx):
    def hook_func(module, input, output):
        out = output.detach().half().reshape(-1)
        out = out[rand_idx]
        feats[layer].append(
            out
        )  # half makes it become float16, reshape(-1) vectorizes it

    return hook_func


hook_handle = []
count = 0
for idx in layers:
    if idx == "fc":
        lay = getattr(resnet18, idx)
        hook_handle.append(
            lay.register_forward_hook(wrapper_hook(layers[count], rand_idx[count]))
        )
        count += 1
    else:
        lay = getattr(resnet18, idx)
        hook_handle.append(
            lay[1].conv2.register_forward_hook(
                wrapper_hook(layers[count], rand_idx[count])
            )
        )
        count += 1


feats = {"layer1": [], "layer2": [], "layer3": [], "layer4": [], "fc": []}

for i in range(2):
    ret, frame = reader.read()
    if ret == False:
        break
    # end if ret==False:
    frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    frame = preprocess(frame).unsqueeze(0)
    print("\nNEW FRAME")
    with torch.no_grad():
        out = resnet18(frame)
        top5 = torch.topk(out, 5)
        for idx in top5.indices[0]:
            print(categories[idx.item()])
# end for i in range(1):
# %%
irun = 5
path2mod = "/Volumes/TIZIANO/models"
with h5py.File(f"{path2mod}/Project1917_resnet18_run0{irun}.h5", "w") as f:
    # Iterate over dictionary items and save them in the HDF5 file
    for key, value in feats.items():
        f.create_dataset(key, data=value)  # Create a dataset for each key-value pair
# %%
