import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# 🔹 Initialize Firebase Admin SDK
cred = credentials.Certificate("./zyppiride-2025-firebase-adminsdk-fbsvc-8888785e38.json")
firebase_admin.initialize_app(cred)

# 🔹 Firestore client
db = firestore.client()

# 🔹 Query approved vehicles // Status : 1 - approved  , 2 - pending , 3 - rejected
approved_ref = db.collection("vehicles").where("documentStatus", "==", "pending")
results = approved_ref.stream()

# 🔹 Prepare data list
vehicles_data = []
for doc in results:
    data = doc.to_dict()
    vehicleDetails = data.get("vehicleDetails", {})

    vehicles_data.append({
        "Vehicle ID": doc.id,
        "User ID": data.get("userId", "N/A"),
        "Brand": vehicleDetails.get("brand", "N/A"),
        "Category": vehicleDetails.get("category", "N/A"),
        "Color": vehicleDetails.get("color", "N/A"),
        "Model": vehicleDetails.get("model", "N/A"),
        "Registration Number": vehicleDetails.get("registrationNumber", "N/A"),
        "Seating Capacity": vehicleDetails.get("seatingCapacity", "N/A"),
        "Year": vehicleDetails.get("year", "N/A"),
        "Document Status": data.get("documentStatus", "N/A"),
        "Created At": data.get("createdAt", None),
        "Insurance Images": ", ".join(data.get("insuranceImages", [])),
        "License Images": ", ".join(data.get("licenseImages", [])),
        "PUC Images": ", ".join(data.get("pucImages", [])),
        "RC Images": ", ".join(data.get("rcImages", [])),
        "Vehicle Images": ", ".join(data.get("vehicleImages", [])),
    })

# 🔹 Convert to pandas DataFrame
df = pd.DataFrame(vehicles_data)

# 🔹 Convert timezone-aware timestamps to string for Excel
if "Created At" in df.columns:
    df["Created At"] = df["Created At"].apply(lambda x: x.strftime('%Y-%m-%d %H:%M:%S') if hasattr(x, 'strftime') else x)

# 🔹 Save to Excel
output_file = "approved_vehicles.xlsx"
df.to_excel(output_file, index=False, engine='openpyxl')

print(f"✅ Excel file '{output_file}' created successfully with {len(df)} approved vehicles.")
