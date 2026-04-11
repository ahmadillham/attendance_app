const prisma = require('../lib/prisma');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { registerValidation, loginValidation } = require('../validations/authValidation');

const registerUser = async (req, res) => {
    try {
        // Validate Data
        const { error } = registerValidation(req.body);
        if (error) return res.status(400).json({ message: error.details[0].message });

        // Check if user exists
        const userExist = await prisma.student.findUnique({ where: { studentId: req.body.studentId } });
        if (userExist) return res.status(400).json({ message: 'Student ID already exists' });

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashPassword = await bcrypt.hash(req.body.password, salt);

        // Create User
        const user = await prisma.student.create({
            data: {
                studentId: req.body.studentId,
                name: req.body.name,
                email: req.body.email,
                phone: req.body.phone,
                department: req.body.department,
                faculty: req.body.faculty,
                semester: req.body.semester,
                password: hashPassword
            }
        });

        res.status(201).json({ message: "Student registered successfully", student: { id: user.id, name: user.name, studentId: user.studentId } });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

const loginUser = async (req, res) => {
    try {
        // Validate Data
        const { error } = loginValidation(req.body);
        if (error) return res.status(400).json({ message: error.details[0].message });

        // Check user
        const user = await prisma.student.findUnique({ where: { studentId: req.body.studentId } });
        if (!user) return res.status(400).json({ message: 'Student ID not found' });

        // Password Check
        const validPass = await bcrypt.compare(req.body.password, user.password);
        if (!validPass) return res.status(400).json({ message: 'Invalid password' });

        // Create token
        if (!process.env.TOKEN_SECRET) {
            return res.status(500).json({ message: 'Server misconfiguration: TOKEN_SECRET is not set' });
        }
        const token = jwt.sign({ id: user.id }, process.env.TOKEN_SECRET, { expiresIn: '1d' });
        
        res.header('Authorization', `Bearer ${token}`).json({ token, studentId: user.studentId, name: user.name });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

module.exports = { registerUser, loginUser };
