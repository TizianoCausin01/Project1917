
# tutorial from https://huggingface.co/docs/transformers/en/model_doc/vitpose
from transformers import AutoProcessor, RTDetrForObjectDetection, VitPoseForPoseEstimation
import torch
import requests
from PIL import Image
import numpy as np
import cv2
import h5py

def fill_in_res(res: list, key: str, size: tuple, top_k: int, box=0): 
    if box == 0:
        data = [res[i][key].cpu().numpy() for i in range(len(res))]
    else:
        data = [np.array([i.cpu().numpy()]) for i in res["scores"]]
    if len(data) < top_k: # fills in if there are less than 5 pers
        fill_in = [np.full(size, np.nan) for _ in range(int(top_k - len(data)))]
        data.extend(fill_in)
    
    data = data[0:5]
    data = np.stack(data, axis=-1) # stacks them along the last dimension
    data = data.flatten(order='F') # vectorizes it fortran style (column-major like matlab)
    return data 
# EOF

feats = {
    "kpts" : [],
    "boxes" : [], 
    "score_boxes" : [],
    "score_kpts" : [], 
    "head_kpts" : [],
    "score_heads" : []
}

# 1 - load video
path2mod = "/leonardo_work/Sis25_piasini/tcausin/Project1917/models"

# 2 - load models
device = "cuda" if torch.cuda.is_available() else "cpu"
person_image_processor = AutoProcessor.from_pretrained("PekingU/rtdetr_r50vd_coco_o365") # loads a preprocessing pipeline img (to ensure same preproc.g)
person_model = RTDetrForObjectDetection.from_pretrained("PekingU/rtdetr_r50vd_coco_o365", device_map=device) # loads the object detection model:  RT-DETR object detection model (detectiion + label.g -> label 0 = person)
#inputs = person_image_processor(images=image, return_tensors="pt").to(device) # preprocesses the image and returns it as a tensor
# returns an object of type <class 'transformers.image_processing_base.BatchFeature'> -> behaves like a dict e.g. inputs.keys() -> 'pixel_values' i.e. the normalized img tensor of shape 2, 3, 256, 192
image_processor = AutoProcessor.from_pretrained("usyd-community/vitpose-base-simple") # downloads a processor tailored for the vitpose-base-simple model, it resizes, normalizes, and formats input data (cropping each detected person), automatically includes COCO keypoint configuration.
model = VitPoseForPoseEstimation.from_pretrained("usyd-community/vitpose-base-simple", device_map=device) #downloads ViTPose

# 3 - read frame and preprocess it
runs = [1,2,3]
for irun in runs  
    path2vid = f"/leonardo_scratch/fast/Sis25_piasini/tcausin/Project1917/stimuli/Project1917_movie_part{irun}_24Hz.mp4"
    reader = cv2.VideoCapture(path2vid)
    while True:
        ret, frame = reader.read()
        
        if ret == False:
            break
        # end if ret==False:
    
        frame_rgb = cv2.cvtColor(
            frame, cv2.COLOR_BGR2RGB
        )  # converts to bgr to rgb color codes
    
        inputs = person_image_processor(frame_rgb, return_tensors="pt")
        
    # 4 - detect people
        with torch.no_grad():
            outputs = person_model(**inputs) # performs object detection on the input
    
    # 5 - get box predictions
        result = person_image_processor.post_process_object_detection(
            outputs, target_sizes=torch.tensor([(frame_rgb.shape[0], frame_rgb.shape[1])]), threshold=0.3 # converts raw model outputs into interpretable bounding box predictions 
        )[0] # selects the first element in the list bc only one img
        
        person_boxes = result["boxes"][result["labels"] == 0] # index only the boxes associated with label 0 (person) in COCO class labels
        
        score_boxes = result["scores"][result["labels"] == 0]
        score_boxes = score_boxes.cpu().numpy()
        # score_boxes_store = fill_in_res(person_boxes, "scores", (1, 1), 5) 
        # feats["score_boxes"].append(score_boxes_store)
        # converts boxes from VOC format: (x1, y1, x2, y2) to COCO format: N pers detected x 4 -> 4 cols are => (x, y, width, height)
        person_boxes[:, 2] = person_boxes[:, 2] - person_boxes[:, 0] 
        person_boxes[:, 3] = person_boxes[:, 3] - person_boxes[:, 1] 
        
    # 6 - preprocess for kpt detection
        inputs = image_processor(frame_rgb, boxes=[person_boxes], return_tensors="pt").to(device) # processes the original image using the bounding boxes -> ViTPose expects tightly cropped pics
        # inputs is a dict like type with "pixels_value" as only entry. It is a tensor [Batch, Channels, Height, Width] -> Batch is the number of people detected
        with torch.no_grad():
            outputs = model(**inputs) # runs ViTPose
        pose_results = image_processor.post_process_pose_estimation(outputs, boxes=[person_boxes])[0]
        kpts_store = fill_in_res(pose_results, "keypoints", (17,2), 5)
        kpts_scores_store = fill_in_res(pose_results, "scores", (17), 5)
        person_boxes_store = fill_in_res(pose_results, "bbox", (4), 5) 
        score_boxes_store = fill_in_res(result, "scores", (1), 5, box=1)
        feats["boxes"].append(person_boxes_store) # FIXME it's a list of dicts
        feats["kpts"].append(kpts_store)
        feats["score_kpts"].append(kpts_scores_store)
        feats["score_boxes"].append(score_boxes_store)
        with h5py.File(f"{path2mod}/Project1917_ViTPose_run0{irun}.h5", "w") as f:
            # Iterate over dictionary items and save them in the HDF5 file
            for key, value in feats.items():
                f.create_dataset(key, data=value)  # Create a dataset for each key-value pair
