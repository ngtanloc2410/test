const API_KEY = "AIzaSyAzAB1sPeH7rWrql3hqXsizFxCsZzFXvqA";
const MODEL_NAME = "gemini-3.1-flash-lite-preview";

let isProcessing = false;
let isTypingFiller = false;

// HÀM QUAN TRỌNG: Giả lập nhập liệu cấp độ trình duyệt
async function robustType(inputElement, text, clear = false) {
    if (!inputElement) return;

    // 1. Click và Focus vào ô nhập liệu để đánh thức các listener
    inputElement.focus();
    inputElement.click();

    if (clear) {
        // Xóa sạch bằng cách chọn tất cả và nhấn Backspace giả lập
        inputElement.select();
        document.execCommand('delete', false, null);
    }

    for (const char of text) {
        // 2. Sử dụng insertText - Đây là cách tốt nhất để "lừa" các framework như Vue/React
        // Nó giả lập hành vi nhập liệu của hệ thống, tự động kích hoạt mọi Event cần thiết
        document.execCommand('insertText', false, char);

        // 3. Vẫn gửi thêm input event cho chắc chắn
        inputElement.dispatchEvent(new Event('input', { bubbles: true }));
        
        // Độ trễ ngẫu nhiên giữa các phím
        await new Promise(r => setTimeout(r, Math.random() * 100 + 50));
    }
}

// Hàm nhập ký tự rác ngẫu nhiên
async function startHumanFiller(inputElement) {
    if (isTypingFiller) return;
    isTypingFiller = true;
    
    console.log("⏳ Đang gõ giả lập để duy trì session...");
    const chars = "abcdefghijklmnopqrstuvwxyz0123456789";

    while (isTypingFiller) {
        if (inputElement.value.length > 5) {
            await robustType(inputElement, "", true); // Xóa nếu dài quá
        }
        
        const randomChar = chars.charAt(Math.floor(Math.random() * chars.length));
        await robustType(inputElement, randomChar);
        
        // Nghỉ lâu một chút (1-3 giây) giữa các lần gõ rác cho giống người
        await new Promise(resolve => setTimeout(resolve, Math.random() * 2000 + 1000));
    }
}

async function solveCaptcha() {
    const captchaImgDiv = document.querySelector('.captcha-image');
    const inputField = document.querySelector('input.inp-dft');
    const submitBtn = document.querySelector('.submit-wrap button');

    if (!captchaImgDiv || !inputField || isProcessing) return;
    
    const bgUrl = window.getComputedStyle(captchaImgDiv).backgroundImage;
    const base64Data = bgUrl.match(/base64,([^"]+)/)?.[1];
    if (!base64Data) return;

    isProcessing = true;
    
    // Bắt đầu gõ rác
    startHumanFiller(inputField);

    try {
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${API_KEY}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{
                    parts: [
                        { text: "Solve this captcha. Output ONLY the characters. No spaces." },
                        { inline_data: { mime_type: "image/png", data: base64Data } }
                    ]
                }]
            })
        });

        const data = await response.json();
        let result = data.candidates[0].content.parts[0].text.trim().replace(/\s/g, '');

        console.log("✅ AI Result:", result);

        // Dừng gõ rác
        isTypingFiller = false;
        await new Promise(r => setTimeout(r, 500));

        // Xóa sạch và điền kết quả chuẩn bằng robustType
        await robustType(inputField, result, true);

        // Đợi 1 chút rồi bấm nộp
        setTimeout(() => {
            if (submitBtn) {
                submitBtn.focus();
                submitBtn.click();
                console.log("🚀 Submitted!");
            }
            isProcessing = false;
        }, 600);

    } catch (error) {
        console.error("❌ Error:", error);
        isTypingFiller = false;
        isProcessing = false;
    }
}

// Theo dõi sự xuất hiện của captcha
const observer = new MutationObserver(() => {
    if (!isProcessing) {
        const captchaImg = document.querySelector('.captcha-image');
        if (captchaImg && window.getComputedStyle(captchaImg).backgroundImage.includes('base64')) {
            solveCaptcha();
        }
    }
});

observer.observe(document.body, { childList: true, subtree: true });

// Check định kỳ dự phòng
setInterval(() => {
    if (!isProcessing) solveCaptcha();
}, 3000);

console.log("🛠️ Robust Human-Like Solver Loaded.");