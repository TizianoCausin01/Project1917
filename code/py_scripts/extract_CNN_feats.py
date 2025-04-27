# %%
# /Users/tizianocausin/Desktop/1917_py_env/bin/activate
# %%
import torch
import cv2
import torchvision.transforms as transforms
import matplotlib.pyplot as plt
from torchvision import models
import numpy as np
import h5py

alexnet = models.alexnet(weights=True).eval()
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

path2vid = "/Volumes/TIZIANO/stimuli/Project1917_movie_part3_24Hz.mp4"
reader = cv2.VideoCapture(path2vid)


def hook_func_conv_l1(module, input, output):
    feats["conv_layer1"].append(
        output.detach().half().reshape(-1)
    )  # half makes it become float16, reshape(-1) vectorizes it


hook_handle_l1 = alexnet.features[1].register_forward_hook(hook_func_conv_l1)


def hook_func_conv_l4(module, input, output):
    feats["conv_layer4"].append(output.detach().half().reshape(-1))


hook_handle_l4 = alexnet.features[4].register_forward_hook(hook_func_conv_l4)


def hook_func_conv_l7(module, input, output):
    feats["conv_layer7"].append(output.detach().half().reshape(-1))


hook_handle_l7 = alexnet.features[7].register_forward_hook(hook_func_conv_l7)


def hook_func_conv_l9(module, input, output):
    feats["conv_layer9"].append(output.detach().half().reshape(-1))


hook_handle_l9 = alexnet.features[9].register_forward_hook(hook_func_conv_l9)


def hook_func_conv_l11(module, input, output):
    feats["conv_layer11"].append(output.detach().half().reshape(-1))


hook_handle_l11 = alexnet.features[11].register_forward_hook(hook_func_conv_l11)


def hook_func_fc_l2(module, input, output):
    feats["fc_layer2"].append(output.detach().half().reshape(-1))


hook_handle_fc_l2 = alexnet.classifier[2].register_forward_hook(hook_func_fc_l2)


def hook_func_fc_l5(module, input, output):
    feats["fc_layer5"].append(output.detach().half().reshape(-1))


hook_handle_fc_l5 = alexnet.classifier[5].register_forward_hook(hook_func_fc_l5)


feats = {
    "conv_layer1": [],
    "conv_layer4": [],
    "conv_layer7": [],
    "conv_layer9": [],
    "conv_layer11": [],
    "fc_layer2": [],
    "fc_layer5": [],
}
# while True:
for i in range(2):
    ret, frame = reader.read()
    if ret == False:
        break
    # end if ret==False:

    frame_rgb = cv2.cvtColor(
        frame, cv2.COLOR_BGR2RGB
    )  # converts to bgr to rgb color codes
    input_tensor = preprocess(frame_rgb).unsqueeze(
        0
    )  # unsqueeze adds the batch size in front of the img
    with torch.no_grad():
        alexnet(input_tensor)
# end for i in range(1):
# %%
irun = 5
path2mod = "/Volumes/TIZIANO/models"
with h5py.File(f"{path2mod}/Project1917_alexnet_run0{irun}.h5", "w") as f:
    # Iterate over dictionary items and save them in the HDF5 file
    for key, value in feats.items():
        f.create_dataset(key, data=value)  # Create a dataset for each key-value pair
# %%
